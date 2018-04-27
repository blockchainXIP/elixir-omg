defmodule OmiseGO.API.State.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Core
  alias OmiseGO.API.TestHelper, as: Test

  @block_interval 1000
  @empty_block_hash <<39, 51, 229, 15, 82, 110, 194, 250, 25, 162, 43, 49, 232, 237, 80, 242, 60,
                      209, 253, 249, 76, 145, 84, 237, 58, 118, 9, 162, 241, 255, 152, 31>>

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can spend deposits", %{alice: alice, bob: bob, state_empty: state} do
    state
    |> Test.do_deposit(alice, %{amount: 10, blknum: 1})
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{bob, 7}, {alice, 3}]), &1)).()
    |> success?
    |> (&Core.exec(Test.create_recovered([{@block_interval, 0, 1, alice}], [{bob, 3}]), &1)).()
    |> success?
  end

  @tag fixtures: [:alice, :state_empty]
  test "can decode deposits in Core", %{alice: alice, state_empty: state} do
    alice_enc = "0x" <> Base.encode16(alice.addr, case: :lower)
    deposits = [%{owner: alice_enc, amount: 10, blknum: 1}]
    assert {_, _, state} =
      deposits
      |> Enum.map(&Core.decode_deposit/1)
      |> Core.deposit(state)

    state
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{alice, 10}]), &1)).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can spend a batch of deposits", %{alice: alice, bob: bob, state_empty: state} do
    state
    |> Test.do_deposit(alice, %{amount: 10, blknum: 1})
    |> Test.do_deposit(bob, %{amount: 20, blknum: 2})
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{bob, 10}]), &1)).()
    |> success?
    |> (&Core.exec(Test.create_recovered([{2, 0, 0, bob}], [{alice, 20}]), &1)).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "ignores deposits from blocks not higher than the block with the last previously received deposit",
       %{
         alice: alice,
         bob: bob,
         state_empty: state
       } do
    deposits = [%{owner: alice.addr, amount: 20, blknum: 2}]
    assert {_, [_, {:put, :last_deposit_block_height, 2}], state} = Core.deposit(deposits, state)

    assert {[], [], ^state} = Core.deposit([%{owner: bob.addr, amount: 20, blknum: 1}], state)
  end

  @tag fixtures: [:bob]
  test "ignores deposits from blocks not higher than the deposit height read from db", %{bob: bob} do
    state = Core.extract_initial_state([], 0, 1, @block_interval)

    assert {[], [], ^state} = Core.deposit([%{owner: bob.addr, amount: 20, blknum: 1}], state)
  end

  @tag fixtures: [:alice, :bob, :state_empty]
  test "can't spend nonexistent", %{alice: alice, bob: bob, state_empty: state} do
    state_deposit = state |> Test.do_deposit(alice, %{amount: 10, blknum: 1})

    state_deposit
    |> (&Core.exec(Test.create_recovered([{1, 1, 0, alice}], [{bob, 7}, {alice, 3}]), &1)).()
    |> fail?(:utxo_not_found)
    |> same?(state_deposit)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit, :state_empty]
  test "amounts must add up", %{alice: alice, bob: bob, state_empty: state} do
    state = Test.do_deposit(state, alice, %{amount: 10, blknum: 1})

    state =
      state
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{alice, 8}, {bob, 3}]), &1)).()
      |> fail?(:amounts_dont_add_up)
      |> same?(state)
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{bob, 8}, {alice, 2}], 1), &1)).()
      |> fail?(:amounts_dont_add_up)
      |> same?(state)
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{bob, 8}, {alice, 3}]), &1)).()
      |> fail?(:amounts_dont_add_up)
      |> same?(state)
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{bob, 2}, {alice, 8}]), &1)).()
      |> success?

    state
    |> (&Core.exec(
          Test.create_recovered([{@block_interval, 0, 0, bob}, {@block_interval, 0, 1, alice}], [
            {alice, 8},
            {bob, 3}
          ]),
          &1
        )).()
    |> fail?(:amounts_dont_add_up)
    |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend other people's funds", %{alice: alice, bob: bob, state_alice_deposit: state} do
    state
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, bob}], [{bob, 8}, {alice, 3}]), &1)).()
    |> fail?(:incorrect_spender)
    |> same?(state)
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, bob}], [{alice, 10}]), &1)).()
    |> fail?(:incorrect_spender)
    |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can't spend spent", %{alice: alice, bob: bob, state_alice_deposit: state} do
    transactions = [
      Test.create_recovered([{1, 0, 0, alice}], [{bob, 7}, {alice, 3}]),
      Test.create_recovered([{0, 0, 0, %{priv: <<>>, addr: nil}}, {1, 0, 0, alice}], [
        {bob, 7},
        {alice, 3}
      ])
    ]

    for first <- transactions,
        second <- transactions do
      state2 = state |> (&Core.exec(first, &1)).() |> success?
      state2 |> (&Core.exec(second, &1)).() |> fail?(:utxo_not_found) |> same?(state2)
    end
  end

  @tag fixtures: [:alice, :bob, :carol, :state_alice_deposit]
  test "can spend change and merge coins", %{
    alice: alice,
    bob: bob,
    carol: carol,
    state_alice_deposit: state
  } do
    state
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{bob, 7}, {alice, 3}]), &1)).()
    |> success?
    |> (&Core.exec(Test.create_recovered([{@block_interval, 0, 0, bob}], [{carol, 7}]), &1)).()
    |> success?
    |> (&Core.exec(Test.create_recovered([{@block_interval, 0, 1, alice}], [{carol, 3}]), &1)).()
    |> success?
    |> (&Core.exec(
          Test.create_recovered([{@block_interval, 1, 0, carol}, {@block_interval, 2, 0, carol}], [
            {alice, 10}
          ]),
          &1
        )).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "can spend after block is formed", %{alice: alice, bob: bob, state_alice_deposit: state} do
    next_block_height = 2 * @block_interval
    {:ok, {_, _, _, state}} = Core.form_block(state, @block_interval, next_block_height)

    state
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{bob, 7}, {alice, 3}]), &1)).()
    |> success?
    |> (&Core.exec(Test.create_recovered([{next_block_height, 0, 0, bob}], [{bob, 7}]), &1)).()
    |> success?
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block doesn't unspend", %{alice: alice, bob: bob, state_alice_deposit: state} do
    recovered = Test.create_recovered([{1, 0, 0, alice}], [{bob, 7}, {alice, 3}])

    {:ok, {_, _, _, state}} =
      state
      |> (&Core.exec(recovered, &1)).()
      |> success?
      |> Core.form_block(1 * @block_interval, 2 * @block_interval)

    recovered |> Core.exec(state) |> fail?(:utxo_not_found) |> same?(state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "spending emits event trigger", %{alice: alice, bob: bob, state_alice_deposit: state} do
    recover = Test.create_recovered([{1, 0, 0, alice}], [{bob, 7}, {alice, 3}])

    assert {:ok, {_, [trigger], _, _}} =
             state
             |> (&Core.exec(recover, &1)).()
             |> success?
             |> Core.form_block(1 * @block_interval, 2 * @block_interval)

    assert trigger == %{tx: recover}
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "every spending emits event triggers", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state =
      state
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{bob, 7}, {alice, 3}]), &1)).()
      |> success?
      |> (&Core.exec(Test.create_recovered([{@block_interval, 0, 0, bob}], [{alice, 7}]), &1)).()
      |> success?

    assert {:ok, {_, [_trigger1, _trigger2], _, _}} =
             Core.form_block(state, 1 * @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "only successful spending emits event trigger", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state
    |> (&Core.exec(Test.create_recovered([{1, 1, 0, alice}], [{bob, 7}, {alice, 3}]), &1)).()
    |> same?(state)

    assert {:ok, {_, [], _, _}} = Core.form_block(state, 1 * @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :state_empty]
  test "deposits emit event triggers, they don't leak into next block", %{
    alice: alice,
    state_empty: state
  } do
    assert {[trigger], _, state} =
             Core.deposit([%{owner: alice, amount: 4, blknum: @block_interval}], state)

    assert trigger == %{deposit: %{owner: alice, amount: 4}}
    assert {:ok, {_, [], _, _}} = Core.form_block(state, @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "empty blocks emit empty event triggers", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state =
      state
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{bob, 7}, {alice, 3}]), &1)).()
      |> success?

    next_block_height = 2 * @block_interval

    assert {:ok, {_, [_trigger], _, state}} =
             Core.form_block(state, @block_interval, next_block_height)

    assert {:ok, {_, [], _, _}} =
             Core.form_block(state, next_block_height, next_block_height + @block_interval)
  end

  @tag fixtures: [:stable_alice, :stable_bob, :state_stable_alice_deposit]
  test "forming block puts all transactions in a block", %{
    stable_alice: alice,
    stable_bob: bob,
    state_stable_alice_deposit: state
  } do
    recovered_tx_1 = Test.create_recovered([{1, 0, 0, alice}], [{bob, 7}, {alice, 3}], 0)

    recovered_tx_2 =
      Test.create_recovered([{@block_interval, 0, 0, bob}], [{alice, 2}, {bob, 5}], 0)

    state =
      state
      |> (&Core.exec(recovered_tx_1, &1)).()
      |> success?
      |> (&Core.exec(recovered_tx_2, &1)).()
      |> success?

    expected_block = %Block{
      transactions: [recovered_tx_1, recovered_tx_2],
      hash:
        <<166, 149, 246, 209, 144, 15, 143, 85, 224, 230, 228, 51, 1, 242, 85, 166, 162, 138, 204,
          220, 45, 30, 102, 107, 5, 173, 160, 181, 187, 25, 232, 33>>
    }

    {:ok, {exp_block, _, _, _}} = Core.form_block(state, 1 * @block_interval, 2 * @block_interval)
    assert exp_block == expected_block

    assert {:ok, {^expected_block, _, _, _}} =
             Core.form_block(state, 1 * @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "forming block empty block after a non-empty block", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    state =
      state
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{bob, 7}, {alice, 3}]), &1)).()
      |> success?

    next_block_height = 2 * @block_interval
    {:ok, {_, _, _, state}} = Core.form_block(state, @block_interval, next_block_height)
    expected_block = empty_block()

    {:ok, {^expected_block, _, _, _}} =
      Core.form_block(state, next_block_height, next_block_height + @block_interval)
  end

  @tag fixtures: [:state_empty]
  test "return error when current block numbers do not match when forming block", %{
    state_empty: state
  } do
    assert {:error, :invalid_current_block_number} == Core.form_block(state, 2, 3)
  end

  @tag fixtures: [:state_empty]
  test "no pending transactions at start (no events, empty block, no db updates)", %{
    state_empty: state
  } do
    expected_block = empty_block()

    assert {:ok, {^expected_block, [], [{:put, :block, ^expected_block}], _}} =
             Core.form_block(state, @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "spending produces db updates, that don't leak to next block", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state
  } do
    {:ok, {_, _, db_updates, state}} =
      state
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{bob, 7}, {alice, 3}]), &1)).()
      |> success?
      |> Core.form_block(1 * @block_interval, 2 * @block_interval)

    assert [
             {:put, :utxo, new_utxo1},
             {:put, :utxo, new_utxo2},
             {:delete, :utxo, {1, 0, 0}},
             {:put, :block, _}
           ] = db_updates

    assert new_utxo1 == %{{@block_interval, 0, 0} => %{owner: bob.addr, amount: 7}}
    assert new_utxo2 == %{{@block_interval, 0, 1} => %{owner: alice.addr, amount: 3}}

    assert {:ok, {_, _, [{:put, :block, _}], state}} =
             Core.form_block(state, 2 * @block_interval, 3 * @block_interval)

    # check double inputey-spends
    {:ok, {_, _, db_updates2, state}} =
      state
      |> (&Core.exec(
            Test.create_recovered([{@block_interval, 0, 0, bob}, {@block_interval, 0, 1, alice}], [
              {bob, 10}
            ]),
            &1
          )).()
      |> success?
      |> Core.form_block(3 * @block_interval, 4 * @block_interval)

    assert [
             {:put, :utxo, new_utxo},
             {:delete, :utxo, {@block_interval, 0, 0}},
             {:delete, :utxo, {@block_interval, 0, 1}},
             {:put, :block, _}
           ] = db_updates2

    assert new_utxo == %{{3 * @block_interval, 0, 0} => %{owner: bob.addr, amount: 10}}

    assert {:ok, {_, _, [{:put, :block, _}], _}} =
             Core.form_block(state, 4 * @block_interval, 5 * @block_interval)
  end

  @tag fixtures: [:alice, :state_empty]
  test "depositing produces db updates, that don't leak to next block", %{
    alice: alice,
    state_empty: state
  } do
    assert {_, [utxo_update, height_update], state} =
             Core.deposit([%{owner: alice.addr, amount: 10, blknum: 1}], state)

    assert utxo_update == {:put, :utxo, %{{1, 0, 0} => %{owner: alice.addr, amount: 10}}}
    assert height_update == {:put, :last_deposit_block_height, 1}

    assert {:ok, {_, _, [{:put, :block, _}], _}} =
             Core.form_block(state, @block_interval, 2 * @block_interval)
  end

  @tag fixtures: [:state_empty]
  test "empty blocks are pushed to db", %{state_empty: state} do
    {:ok, {_, _, db_updates, _}} = Core.form_block(state, @block_interval, 2 * @block_interval)
    is_block_put? = fn {operation, type, _} -> operation == :put && type == :block end
    assert Enum.count(db_updates, is_block_put?) == 1
    expected_block = empty_block()
    assert {:put, :block, ^expected_block} = Enum.find(db_updates, is_block_put?)
  end

  @tag fixtures: [:alice]
  test "utxos get initialized by query result from db and are spendable", %{alice: alice} do
    state =
      Core.extract_initial_state(
        [%{{1, 0, 0} => %{amount: 10, owner: alice.addr}}],
        0,
        1,
        @block_interval
      )

    state
    |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{alice, 7}, {alice, 3}]), &1)).()
    |> success?
  end

  test "core generates the db query" do
    # NOTE: trivial test, considering current behavior, but might evolve... hm
    # FIXME
  end

  @tag fixtures: [:alice, :state_alice_deposit]
  test "spends utxo when exiting", %{alice: alice, state_alice_deposit: state} do
    state =
      state
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{alice, 7}, {alice, 3}]), &1)).()
      |> success?

    expected_owner = alice.addr
    {[%{exit: %{owner: ^expected_owner, blknum: @block_interval, txindex: 0, oindex: 0}},
      %{exit: %{owner: ^expected_owner, blknum: @block_interval, txindex: 0, oindex: 1}}],
     [{:delete, :utxo, {@block_interval, 0, 0}}, {:delete, :utxo, {@block_interval, 0, 1}}],
     state} =
      [%{owner: alice.addr, blknum: @block_interval, txindex: 0, oindex: 0},
       %{owner: alice.addr, blknum: @block_interval, txindex: 0, oindex: 1}]
      |> Core.exit_utxos(state)

    state
    |> (&Core.exec(Test.create_recovered([{@block_interval, 1, 0, alice}], [{alice, 7}]), &1)).()
    |> fail?(:utxo_not_found)
    |> same?(state)
    |> (&Core.exec(Test.create_recovered([{@block_interval, 1, 1, alice}], [{alice, 3}]), &1)).()
    |> fail?(:utxo_not_found)
    |> same?(state)
  end

  @tag fixtures: [:alice, :state_alice_deposit]
  test "does not change when exiting spent utxo", %{alice: alice, state_alice_deposit: state} do
    state =
      state
      |> (&Core.exec(Test.create_recovered([{1, 0, 0, alice}], [{alice, 7}, {alice, 3}]), &1)).()
      |> success?

    {[], [], ^state} =
      [%{owner: alice.addr, blknum: 1, txindex: 0, oindex: 0}]
      |> Core.exit_utxos(state)
  end

  @tag fixtures: [:state_empty]
  test "does not change when exiting non-existent utxo", %{state_empty: state} do
    {[], [], ^state} =
      [%{owner: "owner", blknum: 1, txindex: 0, oindex: 0}]
      |> Core.exit_utxos(state)
  end

  defp success?(result) do
    assert {:ok, state} = result
    state
  end

  defp fail?(result, expected_error) do
    assert {{:error, ^expected_error}, state} = result
    state
  end

  defp same?({{:error, _someerror}, state}, expected_state) do
    assert expected_state == state
    state
  end

  defp same?(state, expected_state) do
    assert expected_state == state
    state
  end

  defp empty_block do
    %Block{transactions: [], hash: @empty_block_hash}
  end
end
