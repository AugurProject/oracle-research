# Large Language Model Oracle With Data Provenance
This document describes an oracle for prediction markets that retrieves data from external websites, gathers cryptographic evidence of the data’s provenance, and resolves the market using a deterministic large language model.

## The Protocol 
A prediction market is created with the following parameters fixed at deployment time:
 - A deterministic large language model
 - A predefined set of external data sources and their public keys
 - A deterministic toolchain (eg, curl, parsing)
 - market question, description, resolution time, outcome options

All participants agree upfront on the complete execution specification.

## 1 Resolution Phase
After the market resolves:

1. A resolver runs the Large Language Model inside the agreed deterministic environment and a task that it should resolve the prediction market according to the websites given.
2. Whenever the Large Language Model performs a web request, the raw response is recorded and a cryptographic proof is obtained that the response originated from the claimed website along with a website provided timestamp
3. All fetched data is stored and recorded

The resolver submits on-chain:
 - Final resolution result.
 - All external data used.
 - Proofs that each piece of data originated from the declared source.

## 2 Verification Phase
Once all data is recorded on-chain, anyone can verify the provenance by either re-executing the protocol using the submitted website data instead of live requests or by validating the zero-knowledge proof produced by the resolver. During verification, it is confirmed that each piece of data carries a valid signature from its respective website, originates from the declared source, and includes timestamps ensuring it was current at the time of market resolution rather than before.

If multiple resolutions are submitted, the first valid resolution is considered as final.

## Technological challenges
There's couple technological challenges with the design:
- A lot data is generated, all this data need to be accessible for anyone. For this eg, [IPFS](https://ipfs.tech/) or Ethereum Blob storage might be used. Other approach is to try to limit the payload size coming from webpages
- The websites need to sign the data they provide. Currently it seems like no websites are doing this, even thought there could be protocols that achieve this (eg, OAuth and [JWT](https://www.jwt.io/)). [TLS-notary](https://tlsnotary.org/) or [DECO](https://www.deco.works/) sound like reasonable options, but they require interactive multiparty computation.
- The Large Language Model needs to be deterministic
- We need to be able to prove Large Language Model execution. Here [Cartesi](https://cartesi.io/) could work. Proving execution with ZK could be nice, but technically too hard.
- The model can hallucinate. This probability should be minimized
- The websites can trick the Large Language Model to resolve wrong with prompt injections. This can be alleviated by running the Large Language Model in separate context for each website and each website vote the market to resolve in certain way, then the votes are tallied and majority vote wins.
