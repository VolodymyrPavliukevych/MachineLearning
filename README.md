# MachineLearning

High-level machine learning APIs for [Swift for TensorFlow](https://github.com/tensorflow/swift).

### Requirements

* Swift for TensorFlow toolchain

Note: For now, you need to build a Swift for TensorFlow toolchain from
[HEAD](https://github.com/apple/swift/tree/tensorflow).

### Build instructions

```bash
swift build -Xswiftc -Xllvm -Xswiftc -tf-dynamic-compilation
```
