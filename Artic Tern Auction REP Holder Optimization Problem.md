## Artic Tern Auction REP Holder Optimization Problem
When Artic Tern forks it attempts to raise $ETH$ to make open interest holders in expense of $REP$ holders.

If $REP$ holder assumes that the $REP$ acquisition cost in the auction is lower than current price, they should sell their $REP$ before fork and buy it back in the auction. This should align pre-fork $REP$ price to be closer to auction price.

## REP Holders Optimization Problem

$REP$ holder should maximize the following function:
```math
\max_{\text{Bought REP}} \quad \text{FDV} \cdot \frac{\text{Your REP} + \text{Bought REP}}{\text{Migrated REP Supply} + \text{Minted REP}} - \text{Acquisition Cost}
```

**Subject to:**

1. Definition of acquisition cost:

```math
\text{Bought REP} = \frac{\text{Acquisition Cost}}{\text{REP Price}}
```

2. Minting constraint:

```math
\text{Bought REP} \leq \text{Minted REP}
```

3. Lower bound (can't sell more than you have):

```math
\text{Bought REP} \geq -\text{Your REP}
```

If we assume we are the only auction participant ($\text{Bought REP} = \text{Minted REP}$) we get:
```math
\text{Profit} = \text{FDV} \cdot \frac{\text{Your REP} + \text{Minted REP}}{\text{Migrated REP Supply} + \text{Minted REP}} - \text{Minted REP} \cdot \text{REP Price}
```

$REP$ holder should buy all the $REP$ from the auction if:
$$
\boxed{
\text{Profit} > 0 \quad \text{if and only if} \quad
\text{REP Price} < \frac{\text{FDV}}{\text{Minted REP}} \cdot \frac{\text{Your REP} + \text{Minted REP}}{\text{Migrated REP Supply} + \text{Minted REP}}
}
$$
