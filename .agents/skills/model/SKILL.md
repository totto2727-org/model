---
name: model
description: Choose Serde or Garde when mapping a MoonBit type to a JSON contract or converting wire data into a validated model with totto2727/model.
---

# Model for MoonBit

If the MoonBit type already matches the wire format, prefer the standard JSON derivation. Use [Serde](https://github.com/totto2727-org/model/blob/main/src/serde-codegen/README.mbt.md) when wire names, paths, or defaults differ. Test a real wire example: a round trip alone can hide a codec that reads and writes the same wrong key.

Successful decoding does not establish domain validity. Use [Garde](https://github.com/totto2727-org/model/blob/main/src/garde/README.mbt.md#typed-model-conversion) when you need validation or a typed conversion. When converting a wire record with `to_decoded()`, handle its validation result rather than validating twice.

For generator setup, use the [consumer guide](https://github.com/totto2727-org/model/blob/main/README.mbt.md#generate-code-with-dev_build) from the same revision as the library.
