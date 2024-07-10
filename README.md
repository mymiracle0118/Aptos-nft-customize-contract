# Jarvis Aptos NFT

This is a cusomized NFT based on object.

## How to compile(=build)

! I recommend testnet for checking & developing !

First, you need to create aptos account. `aptos init`
Second, you need to modify `dropspace` value with your aptos account in `Move.toml`.
Third, you need to compile or publish your module
    compile: `aptos move compile`
    publish: `aptos move publish`

Note: For singer cap, We use hardcoded `seed` as `x"450.."`, so If you are trying to redeploy this module, you need to change this seed

