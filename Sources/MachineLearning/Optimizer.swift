// Copyright 2018 The TensorFlow Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import TensorFlow

public protocol Optimizer: AnyObject {
    associatedtype Model: Layer
    associatedtype Scalar: FloatingPoint
    var learningRate: Scalar { get }
    func fit(_ model: inout Model, along gradient: Model.CotangentVector)
}

// MARK: - Key-path based optimizers

public class Adam<Model: Layer, Scalar: BinaryFloatingPoint & TensorFlowScalar>: Optimizer
    where Model.AllDifferentiableVariables: AdditiveArithmetic,
          Model.AllDifferentiableVariables == Model.CotangentVector {
    public let learningRate: Scalar
    public var beta1: Scalar
    public var beta2: Scalar
    public let epsilon: Scalar
    public let decay: Scalar

    public init(
        learningRate: Scalar = 1e-3,
        beta1: Scalar = 0.9,
        beta2: Scalar = 0.999,
        epsilon: Scalar = 1e-8,
        decay: Scalar = 0
    ) {
        precondition(learningRate >= 0, "Learning rate must be non-negative")
        precondition(0 <= beta1 && beta1 <= 1, "Beta parameter must be between 0 and 1")
        precondition(0 <= beta2 && beta2 <= 1, "Beta parameter must be between 0 and 1")
        precondition(decay >= 0, "Weight decay must be non-negative")

        self.learningRate = learningRate
        self.beta1 = beta1
        self.beta2 = beta2
        self.epsilon = epsilon
        self.decay = decay
    }

    private var step: Scalar = 0
    private var firstMoments = Model.AllDifferentiableVariables.zero
    private var secondMoments = Model.AllDifferentiableVariables.zero

    public func fit(_ model: inout Model, along gradients: Model.CotangentVector) {
        for kp in model.allDifferentiableVariables
                       .recursivelyAllWritableKeyPaths(to: Tensor<Scalar>.self) {
            firstMoments[keyPath: kp] =
                firstMoments[keyPath: kp] * beta1 + (1 - beta1) * gradients[keyPath: kp]
            secondMoments[keyPath: kp] =
                firstMoments[keyPath: kp] * beta2 + (1 - beta2) *
                gradients[keyPath: kp] * gradients[keyPath: kp]

            let denominator = sqrt(secondMoments[keyPath: kp]) + epsilon
            step += 1
            let biasCorrection1 = 1 - pow(beta1, step)
            let biasCorrection2 = 1 - pow(beta2, step)
            let stepSize = learningRate * sqrt(biasCorrection2) / biasCorrection1
            model.allDifferentiableVariables[keyPath: kp] -=
                stepSize * firstMoments[keyPath: kp] / denominator
        }
    }
}

public class RMSProp<Model: Layer, Scalar: BinaryFloatingPoint & TensorFlowScalar>: Optimizer
    where Model.AllDifferentiableVariables: AdditiveArithmetic,
          Model.AllDifferentiableVariables == Model.CotangentVector {
    public let learningRate: Scalar
    public let rho: Scalar
    public let epsilon: Scalar
    public let decay: Scalar

    public init(
        learningRate: Scalar = 0.001,
        rho: Scalar = 0.9,
        epsilon: Scalar = 1e-8,
        decay: Scalar = 0
    ) {
        precondition(learningRate >= 0, "Learning rate must be non-negative")
        precondition(rho >= 0, "Rho must be non-negative")
        precondition(decay >= 0, "Weight decay must be non-negative")

        self.learningRate = learningRate
        self.rho = rho
        self.epsilon = epsilon
        self.decay = decay
    }

    private var alpha = Model.AllDifferentiableVariables.zero

    public func fit(_ model: inout Model, along gradients: Model.CotangentVector) {
        for kp in model.allDifferentiableVariables
                       .recursivelyAllWritableKeyPaths(to: Tensor<Scalar>.self) {
            alpha[keyPath: kp] =
                rho * alpha[keyPath: kp] + (1 - rho) * pow(gradients[keyPath: kp], 2)
            model.allDifferentiableVariables[keyPath: kp] -=
                learningRate * gradients[keyPath: kp] / (sqrt(alpha[keyPath: kp]) + epsilon)
        }
    }
}

public class SGD<Model: Layer, Scalar: BinaryFloatingPoint & TensorFlowScalar>: Optimizer
    where Model.AllDifferentiableVariables: AdditiveArithmetic,
          Model.AllDifferentiableVariables == Model.CotangentVector {
    public let learningRate: Scalar
    public let momentum: Scalar
    public let decay: Scalar
    public let nesterov: Bool

    public init(
        learningRate: Scalar = 0.01,
        momentum: Scalar = 0,
        decay: Scalar = 0,
        nesterov: Bool = false
    ) {
        precondition(learningRate >= 0, "Learning rate must be non-negative")
        precondition(momentum >= 0, "Momentum must be non-negative")
        precondition(decay >= 0, "Weight decay must be non-negative")

        self.learningRate = learningRate
        self.momentum = momentum
        self.decay = decay
        self.nesterov = nesterov
    }

    private var velocity = Model.AllDifferentiableVariables.zero

    public func fit(_ model: inout Model, along gradients: Model.CotangentVector) {
        for kp in model.allDifferentiableVariables
                       .recursivelyAllWritableKeyPaths(to: Tensor<Scalar>.self) {
            velocity[keyPath: kp] =
                momentum * velocity[keyPath: kp] - learningRate * gradients[keyPath: kp]
            let modelKP = (\Model.allDifferentiableVariables).appending(path: kp)
            if nesterov {
                model[keyPath: modelKP] +=
                    momentum * velocity[keyPath: kp] - learningRate * gradients[keyPath: kp]
            } else {
                model[keyPath: modelKP] += velocity[keyPath: kp]
            }
        }
    }
}

// MARK: - Manifold optimizers

public class RiemannSGD<Model: Layer, Scalar: FloatingPoint> : Optimizer
    where Model.TangentVector: VectorNumeric, Model.TangentVector.Scalar == Scalar {
    public var learningRate: Scalar

    public init(learningRate: Scalar) {
        self.learningRate = learningRate
    }

    public func fit(_ model: inout Model, along gradient: Model.CotangentVector) {
        model = model.moved(along: learningRate * (.zero - model.tangentVector(from: gradient)))
    }
}
