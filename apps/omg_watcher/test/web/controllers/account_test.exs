# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.Web.Controller.AccountTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures

  alias OMG.API
  alias OMG.API.Crypto
  alias OMG.API.TestHelper
  alias OMG.Watcher.DB
  alias OMG.Watcher.TestHelper

  @eth_hex String.duplicate("00", 20)
  @other_token <<127::160>>
  @other_token_hex @other_token |> Base.encode16()

  describe "Controller.AccountTest" do
    @tag fixtures: [:initial_blocks, :alice, :bob]
    test "Account balance groups account tokens and provide sum of available funds",
         %{alice: alice, bob: bob} do
      assert %{
               "result" => "success",
               "data" => [%{"currency" => @eth_hex, "amount" => 349}]
             } == TestHelper.rest_call(:post, "/account.get_balance", body_for(bob), 200)

      # adds other token funds for alice to make more interesting
      DB.Transaction.update_with(%{
        transactions: [
          API.TestHelper.create_recovered([], @other_token, [{alice, 121}, {alice, 256}])
        ],
        blknum: 11_000,
        blkhash: <<?#::256>>,
        timestamp: :os.system_time(:second),
        eth_height: 10
      })

      %{
        "result" => "success",
        "data" => data
      } = TestHelper.rest_call(:post, "/account.get_balance", body_for(alice), 200)

      assert [
               %{"currency" => @eth_hex, "amount" => 201},
               %{"currency" => @other_token_hex, "amount" => 377}
             ] == data |> Enum.sort(&(Map.get(&1, "currency") <= Map.get(&2, "currency")))
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "Account balance for non-existing account responds with empty array" do
      no_account = %{addr: <<0::160>>}

      assert %{"result" => "success", "data" => []} ==
               TestHelper.rest_call(:post, "/account.get_balance", body_for(no_account), 200)
    end
  end

  defp body_for(%{addr: address}) do
    {:ok, address_encode} = Crypto.encode_address(address)
    %{"address" => address_encode}
  end
end
