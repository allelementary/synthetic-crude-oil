# Synthetic Crude Oil Token

Tokenized Crude Oil smart contract provides broader access to trading and investment opportunities. It enables fractional trading of crude oil assets, reducing barriers and bypassing bureaucratic restrictions, allowing for more efficient and inclusive participation.

## About

Collateral: WETH / DAI
Stability Mechanism: Algorithmic
Using: Chainlink price feeds, Chainlink CCIP

Synthetic Crude Oil Token (sOIL) is not backed by a real-world commodity but rather by other cryptocurrencies, specifically WETH and DAI. DAI was chosen over other stablecoins because of its decentralized nature.

To mint sOIL, users deposit either WETH or DAI. To maintain price stability, sOIL requires 150% over-collateralization. For instance, to mint $100 worth of sOIL, a user must lock $150 worth of WETH or DAI. If the collateral or underlying asset prices fluctuate, causing the collateralization rate to drop below 150%, the position can be liquidated by other users who receive a 10% bonus in the underlying asset.

### Liquidation mechanism

The liquidation mechanism ensures that the asset's value closely aligns with its underlying collateral. This is a common practice for stablecoins to keep their value pegged, usually around $1. When a stablecoin is backed by real dollars, the amount in the bank should match the number of tokens minted.

In our case, we aim for the synthetic crude oil token (sOIL) to mirror the value of real crude oil. To achieve this, users must maintain collateral assets exceeding the value of the sOIL they have minted. Due to the volatility of the underlying assets, a 1:1 collateral-to-token ratio would likely result in frequent liquidations. Therefore, over-collateralization is required.

If the health factor of a position drops below a specific threshold—for instance, if the collateral value falls below 150% of the sOIL value (a 1:1.5 ratio)—other users can liquidate that position. In the liquidation process, the minted sOIL is burned, and the liquidator receives the underlying collateral at a 10% discount as a reward. This discount incentivizes liquidators to maintain the system's stability.
