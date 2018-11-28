# Watcher

API specification of the Watcher's security-critical Service

## Account - Get Utxos

```shell
http POST /account.get_utxos address=b3256026863eb6ae5b06fa396ab09069784ea8ea
```

```elixir
// TODO
```

```javascript
// TODO
```

> The above command returns JSON document:

```json
{
    "version": "1",
    "success": true,
    "data": [
        {
            "txindex": 1,
            "owner": "B3256026863EB6AE5B06FA396AB09069784EA8EA",
            "oindex": 0,
            "currency": "0000000000000000000000000000000000000000",
            "blknum": 1000,
            "amount": 10
        }
    ]
}
```

Gets all utxos belonging to the given address.
<aside class="warning"> Note that this is a performance intensive call and should only be used if the chain is byzantine and the user needs to retrieve utxo information to be able to exit. Normally an application should use the Informational API `/account.get_utxos`. This version is provided in case the Informational API is not available.</aside> 


### HTTP Request

`POST /account.get_utxos`

### JSON Body

Key | Type | Description
--------- | ------- | -----------
address | Hex encoded string | Address of the account
limit | Integer | Maximum number of utxos to return (optional)



## Utxo - Get Challenge Data

```shell
http POST /utxo.get_challenge_data utxo_pos=10001001
```

```elixir
// TODO
```

```javascript
// TODO
```

> The above command returns JSON document:

```json
{
    "version": "1",
    "success": true,
    "data": {
        "txbytes": "F849822AF880808080809400000000000000000000000000000000000000009489F5AD3F771617E853451A93F7A73E48CF5550D104948CE5C73FD5BEFFE0DCBCB6AFE571A2A3E73B043C03",
        "sigs": "6BFB9B2DBE3201BDC48072E69148A0ED9AF3E01D87772C8A77A478F998CEB5236B0AE64FAB3C21C078188B162D86913010A988E4B0CE68EE95D86783008FD9C71B0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "proof": "0000000000000000000000000000000000000000000000000000000000000000AD3228B676F7D3CD4284A5443F17F1962B36E491B30A40B2405849E597BA5FB5B4C11951957C6F8F642C4AF61CD6B24640FEC6DC7FC607EE8206A99E92410D3021DDB9A356815C3FAC1026B6DEC5DF3124AFBADB485C9BA5A3E3398A04B7BA85E58769B32A1BEAF1EA27375A44095A0D1FB664CE2DD358E7FCBFB78C26A193440EB01EBFC9ED27500CD4DFC979272D1F0913CC9F66540D7E8005811109E1CF2D887C22BD8750D34016AC3C66B5FF102DACDD73F6B014E710B51E8022AF9A1968FFD70157E48063FC33C97A050F7F640233BF646CC98D9524C6B92BCF3AB56F839867CC5F7F196B93BAE1E27E6320742445D290F2263827498B54FEC539F756AFCEFAD4E508C098B9A7E1D8FEB19955FB02BA9675585078710969D3440F5054E0F9DC3E7FE016E050EFF260334F18A5D4FE391D82092319F5964F2E2EB7C1C3A5F8B13A49E282F609C317A833FB8D976D11517C571D1221A265D25AF778ECF8923490C6CEEB450AECDC82E28293031D10C7D73BF85E57BF041A97360AA2C5D99CC1DF82D9C4B87413EAE2EF048F94B4D3554CEA73D92B0F7AF96E0271C691E2BB5C67ADD7C6CAF302256ADEDF7AB114DA0ACFE870D449A3A489F781D659E8BECCDA7BCE9F4E8618B6BD2F4132CE798CDC7A60E7E1460A7299E3C6342A579626D2",
        "eutxoindex": "200001001",
        "cutxopos": "100001001"
    }
}
```

Gets challenge data for a given utxo exit

### HTTP Request

`POST /utxo.get_challenge_data`

### JSON Body

Key | Type | Description
--------- | ------- | -----------
utxo_pos | Integer | Utxo position (encoded as single integer, the way contract represents them)



## Utxo - Get Exit Data

```shell
http POST /utxo.get_exit_data utxo_pos=10001001
```

```elixir
// TODO
```

```javascript
// TODO
```

> The above command returns JSON document:

```json
{
    "version": "1",
    "success": true,
    "data": {
        "utxo_pos": 10001001,
        "txbytes": "F84701018080808094000000000000000000000000000000000000000094D27EB36B73F275E3F7CD20A510710F763DE3BF366E94000000000000000000000000000000000000000080",
        "sigs": "7C29FB8327F60BBFC6201DF2FBAAA8D22E5C0CA3D1EB5FF0D37ECDAF61E507FE77DED514AA42A622E5682BF692B33E60D292425C531109841C67B5BD86876CDE1C0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "proof": "CEDB8B31D1E4CB72EC267A8B27C42C4D9982C3F3950D88003F44B3A797202D848025356282CA1C28CBD51FBF7D8E9187AA85F628D054B2C2233AA83BCAEF1F0EB4C11951957C6F8F642C4AF61CD6B24640FEC6DC7FC607EE8206A99E92410D3021DDB9A356815C3FAC1026B6DEC5DF3124AFBADB485C9BA5A3E3398A04B7BA85E58769B32A1BEAF1EA27375A44095A0D1FB664CE2DD358E7FCBFB78C26A193440EB01EBFC9ED27500CD4DFC979272D1F0913CC9F66540D7E8005811109E1CF2D887C22BD8750D34016AC3C66B5FF102DACDD73F6B014E710B51E8022AF9A1968FFD70157E48063FC33C97A050F7F640233BF646CC98D9524C6B92BCF3AB56F839867CC5F7F196B93BAE1E27E6320742445D290F2263827498B54FEC539F756AFCEFAD4E508C098B9A7E1D8FEB19955FB02BA9675585078710969D3440F5054E0F9DC3E7FE016E050EFF260334F18A5D4FE391D82092319F5964F2E2EB7C1C3A5F8B13A49E282F609C317A833FB8D976D11517C571D1221A265D25AF778ECF8923490C6CEEB450AECDC82E28293031D10C7D73BF85E57BF041A97360AA2C5D99CC1DF82D9C4B87413EAE2EF048F94B4D3554CEA73D92B0F7AF96E0271C691E2BB5C67ADD7C6CAF302256ADEDF7AB114DA0ACFE870D449A3A489F781D659E8BECCDA7BCE9F4E8618B6BD2F4132CE798CDC7A60E7E1460A7299E3C6342A579626D2"
    }
}
```

Gets exit data for a given utxo

### HTTP Request

`POST /utxo.get_exit_data`

### JSON Body

Key | Type | Description
--------- | ------- | -----------
utxo_pos | Integer | Utxo position (encoded as single integer, the way contract represents them)



## Transaction - Submit

```shell
http POST /transaction.submit transaction=f8d083015ba98080808080940000...
```

```elixir
// TODO
```

```javascript
// TODO
```

> The above command returns JSON document:
<aside class="warning">Is it OK? Following is planned child chain response for corresponding endpoint</aside> 

```json
{
      "version": "1",
      "success": true,
      "data": { 
          "blknum": 123000,
          "txindex": 111,
          "txhash": "bdf562c24ace032176e27621073df58ce1c6f65de3b5932343b70ba03c72132d"
      }
}
```

Watcher passes signed transaction to the child chain only if it's secure (better explaination needed)

### HTTP Request

`POST /transaction.submit`

### JSON Body

Key | Type | Description
--------- | ------- | -----------
transaction | Hex encoded string | Signed transaction RLP-encoded to bytes and HEX-encoded to string




## Status

```shell
http POST /status
```

```elixir
// TODO
```

```javascript
// TODO
```

> The above command returns JSON document:

```json
{
    "version": "1",
    "success": true,
    "data": {
        "last_validated_child_block_number": 10000,
        "last_mined_child_block_timestamp": 1535031020,
        "last_mined_child_block_number": 11000,
        "eth_syncing": true
    }
}
```

Gets plasma network and Watcher status

### HTTP Request

`POST /status`

### JSON Body

No parameters are required.

