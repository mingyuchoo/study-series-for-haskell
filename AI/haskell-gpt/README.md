# HaskellGPT

A transformer-based language model implemented in pure Haskell, ported from RustGPT.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Haskell](https://img.shields.io/badge/Haskell-9.10.2-purple.svg)](https://www.haskell.org/)
[![Stack](https://img.shields.io/badge/Stack-3.7.1-blue.svg)](https://docs.haskellstack.org/)

## Overview

HaskellGPT is a complete Haskell implementation of a GPT-style transformer language model. This project demonstrates how functional programming principles can be applied to deep learning, featuring a pure functional neural network implementation without external ML frameworks.

### Key Features

- **Pure Functional Implementation**: All neural network components implemented using pure functions with explicit state management
- **Type-Safe Architecture**: Leverages Haskell's type system with type classes for layer abstractions
- **Adam Optimizer**: Adaptive learning rate optimization with momentum
- **Transformer Architecture**: Self-attention mechanism with feed-forward networks and layer normalization
- **Pre-training & Instruction Tuning**: Two-phase training pipeline for general language understanding and task-specific fine-tuning
- **Interactive Chat Mode**: Real-time conversation interface after training
- **Comprehensive Test Suite**: Unit tests for all components using HSpec and QuickCheck

## Table of Contents

- [Architecture](#architecture)
- [Model Configuration](#model-configuration)
- [Project Structure](#project-structure)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Training Data](#training-data)
- [Components](#components)
- [Example Interactions](#example-interactions)
- [Dependencies](#dependencies)
- [Testing](#testing)
- [Learning Resources](#learning-resources)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Architecture

HaskellGPT implements a standard transformer architecture with the following components:

```
Input Text
    │
    ▼
Tokenization
    │
    ▼
Token + Positional Embeddings (128-dim)
    │
    ▼
Transformer Block 1 ──┐
    │                  │
    ▼                  │
Transformer Block 2    │ (Self-Attention + Feed-Forward + LayerNorm)
    │                  │
    ▼                  │
Transformer Block 3 ──┘
    │
    ▼
Output Projection (vocab_size)
    │
    ▼
Softmax → Token Probabilities
    │
    ▼
Greedy Decoding
    │
    ▼
Generated Text
```

### Transformer Block Architecture

Each transformer block consists of:

1. **Self-Attention Layer**: Computes attention scores between all tokens in the sequence
2. **Residual Connection**: Adds input to attention output
3. **Layer Normalization**: Normalizes across embedding dimension
4. **Feed-Forward Network**: Two-layer MLP with ReLU activation (128 → 256 → 128)
5. **Residual Connection**: Adds normalized input to feed-forward output
6. **Layer Normalization**: Final normalization

## Model Configuration

### Hyperparameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Max Sequence Length | 80 | Maximum number of tokens in input/output |
| Embedding Dimension | 128 | Size of token and positional embeddings |
| Hidden Dimension | 256 | Size of feed-forward hidden layer |
| Number of Transformer Blocks | 3 | Depth of the model |
| Attention Heads | 1 | Single-head attention (simplified) |
| Vocabulary Size | Dynamic | Built from training data + special tokens |

### Training Configuration

| Phase | Epochs | Learning Rate | Purpose |
|-------|--------|---------------|---------|
| Pre-training | 100 | 0.0005 | General language understanding |
| Instruction Tuning | 100 | 0.0001 | Task-specific fine-tuning |

### Optimizer Settings

- **Algorithm**: Adam
- **Beta1**: 0.9 (first moment decay)
- **Beta2**: 0.999 (second moment decay)
- **Epsilon**: 1e-8 (numerical stability)
- **Gradient Clipping**: L2 norm ≤ 5.0

## Project Structure

```
HaskellGPT/
├── src/
│   ├── HaskellGPT.hs              # Main library module (re-exports)
│   └── HaskellGPT/
│       ├── Types.hs               # Common types, constants, Layer type class
│       ├── Adam.hs                # Adam optimizer implementation
│       ├── Vocab.hs               # Vocabulary management and tokenization
│       ├── Embeddings.hs          # Token and positional embeddings
│       ├── SelfAttention.hs       # Self-attention mechanism
│       ├── FeedForward.hs         # Feed-forward network with ReLU
│       ├── LayerNorm.hs           # Layer normalization
│       ├── Transformer.hs         # Transformer block (combines components)
│       ├── OutputProjection.hs    # Final projection to vocabulary
│       ├── LLM.hs                 # Main LLM module (training & inference)
│       └── Dataset.hs             # Dataset loader (JSON/CSV)
├── app/
│   └── Main.hs                    # Executable entry point
├── test/
│   ├── Spec.hs                    # Test suite entry point
│   ├── AdamSpec.hs                # Adam optimizer tests
│   ├── VocabSpec.hs               # Vocabulary tests
│   ├── EmbeddingsSpec.hs          # Embeddings tests
│   ├── SelfAttentionSpec.hs       # Self-attention tests
│   ├── FeedForwardSpec.hs         # Feed-forward tests
│   ├── LayerNormSpec.hs           # Layer normalization tests
│   ├── TransformerSpec.hs         # Transformer block tests
│   ├── OutputProjectionSpec.hs    # Output projection tests
│   ├── LLMSpec.hs                 # LLM integration tests
│   └── DatasetSpec.hs             # Dataset loader tests
├── data/
│   ├── pretraining_data.json      # General language training data
│   └── chat_training_data.json    # Instruction-response pairs
├── package.yaml                   # Package configuration (hpack format)
├── stack.yaml                     # Stack configuration
├── HaskellGPT.cabal              # Generated Cabal file
├── README.md                      # This file
└── LICENSE                        # MIT License

```

## Requirements

### System Requirements

- **GHC**: 9.10.2 or compatible
- **Stack**: 3.7.1 or later
- **Operating System**: macOS, Linux, or Windows (with WSL recommended)
- **Memory**: At least 4GB RAM recommended for training
- **BLAS/LAPACK**: Required by hmatrix (usually pre-installed on most systems)

### Haskell Build Tools

You can use either Stack or Cabal:

- **Stack** (recommended): Manages GHC versions and dependencies automatically
- **Cabal**: Requires manual GHC installation

## Installation

### Using Stack (Recommended)

1. **Install Stack** (if not already installed):
   ```bash
   # macOS
   brew install haskell-stack
   
   # Linux
   curl -sSL https://get.haskellstack.org/ | sh
   
   # Windows
   # Download installer from https://docs.haskellstack.org/en/stable/install_and_upgrade/
   ```

2. **Clone the repository**:
   ```bash
   git clone https://github.com/username/HaskellGPT.git
   cd HaskellGPT
   ```

3. **Build the project**:
   ```bash
   stack build
   ```
   
   This will:
   - Download and install GHC 9.10.2 if needed
   - Install all dependencies
   - Compile the project

### Using Cabal

1. **Install GHC 9.10.2** and **cabal-install**

2. **Clone and build**:
   ```bash
   git clone https://github.com/username/HaskellGPT.git
   cd HaskellGPT
   cabal update
   cabal build
   ```

## Usage

### Running the Model

To train and run the model with the provided training data:

```bash
stack run
```

This will:
1. Load training data from `data/` directory
2. Build vocabulary from the training corpus
3. Initialize the model with random weights
4. Perform pre-training (100 epochs)
5. Perform instruction tuning (100 epochs)
6. Enter interactive chat mode

### Interactive Mode

After training completes, you can interact with the model:

```
Entering Interactive Mode...
============================
Type your prompts below. Type 'exit' to quit.

User: Hello
Assistant: Hello! How can I help you today?

User: What is photosynthesis?
Assistant: Photosynthesis is the process by which green plants use sunlight to synthesize food from carbon dioxide

User: exit
```

### Building Only

To build without running:

```bash
stack build
```

### Running Tests

To run the test suite:

```bash
stack test
```

To run tests with verbose output:

```bash
stack test --test-arguments "--format=progress"
```

### Cleaning Build Artifacts

```bash
stack clean
```

## Training Data

### Data Format

Training data is stored in JSON format as arrays of strings:

```json
[
    "Example text for pre-training </s>",
    "Another example sentence </s>",
    "User: Question? Assistant: Answer </s>"
]
```

### Special Tokens

- `[PAD]`: Padding token for sequences
- `[UNK]`: Unknown words not in vocabulary
- `[START]`: Start of sequence marker
- `[END]`: End of sequence marker
- `</s>`: End of sentence/turn marker

### Pre-training Data

Located in `data/pretraining_data.json`. Contains general text for learning language patterns and structure.

### Chat Training Data

Located in `data/chat_training_data.json`. Contains instruction-response pairs in the format:
```
User: [question/prompt] Assistant: [response] </s>
```

### Custom Training Data

You can provide your own training data by:

1. Creating JSON files in the same format
2. Placing them in the `data/` directory
3. Modifying `app/Main.hs` to load your files

## Components

### Layer Type Class

All neural network layers implement the `Layer` type class:

```haskell
class Layer l where
  -- Forward pass: input -> (updated layer with cache, output)
  forward :: l -> Matrix Float -> (l, Matrix Float)
  
  -- Backward pass: gradients -> learning rate -> (updated layer, input gradients)
  backward :: l -> Matrix Float -> Float -> (l, Matrix Float)
  
  -- Get layer type name
  layerType :: l -> String
  
  -- Count trainable parameters
  parameters :: l -> Int
```

### Adam Optimizer

Implements adaptive learning rate optimization:

- Maintains first moment (mean) and second moment (variance) estimates
- Applies bias correction
- Updates parameters with adaptive learning rates

### Vocabulary Management

- Bidirectional mapping between words and token IDs
- O(1) lookup using hash maps
- Handles unknown words gracefully
- Supports special tokens

### Embeddings Layer

- **Token Embeddings**: Learned representations for each vocabulary word
- **Positional Embeddings**: Sinusoidal encodings for sequence positions
- Combined embeddings passed to transformer blocks

### Self-Attention

Computes attention scores between all token pairs:

```
Attention(Q, K, V) = softmax(Q·K^T / √d_k)·V
```

Where Q, K, V are query, key, and value matrices derived from input.

### Feed-Forward Network

Two-layer MLP with ReLU activation:

```
FFN(x) = ReLU(x·W1 + b1)·W2 + b2
```

### Layer Normalization

Normalizes across the embedding dimension:

```
LayerNorm(x) = γ · (x - μ) / (σ + ε) + β
```

Where γ and β are learnable parameters.

### Output Projection

Projects hidden states to vocabulary logits:

```
logits = hidden·W_out + b_out
```

Followed by softmax for probability distribution.

## Example Interactions

### Before Training

```
Before Training Prediction:
  Input: User: Hello
  Output: [UNK] [UNK] [UNK]
```

The model produces random/nonsensical output before training.

### After Training

```
After Training Prediction:
  Input: User: Hello
  Output: Hello! How can I help you today?

User: What causes rain?
Assistant: Rain is caused by water vapor in clouds condensing into droplets that become too heavy to remain airborne

User: How do mountains form?
Assistant: Mountains are formed through tectonic forces or volcanism over long geological time periods

User: What is photosynthesis?
Assistant: Photosynthesis is the process by which green plants use sunlight to synthesize food from carbon dioxide
```

## Dependencies

### Core Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| base | ≥ 4.7 && < 5 | Standard library |
| hmatrix | ≥ 0.20 | Efficient matrix operations with BLAS/LAPACK |
| random | ≥ 1.2 | Random number generation for weight initialization |
| containers | ≥ 0.6 | Map and Set data structures for vocabulary |
| aeson | ≥ 2.0 | JSON parsing for training data |
| bytestring | ≥ 0.11 | Efficient byte string operations |
| text | ≥ 1.2 | Efficient text processing |
| vector | ≥ 0.12 | Efficient array operations |
| cassava | ≥ 0.5 | CSV parsing support |
| mtl | ≥ 2.2 | Monad transformers |

### Test Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| hspec | ≥ 2.8 | Testing framework |
| QuickCheck | ≥ 2.14 | Property-based testing |
| HUnit | ≥ 1.6 | Unit testing utilities |
| temporary | ≥ 1.3 | Temporary file handling for tests |
| filepath | ≥ 1.4 | File path manipulation |

### Installing BLAS/LAPACK

hmatrix requires BLAS/LAPACK for efficient matrix operations:

**macOS**:
```bash
# Usually pre-installed via Accelerate framework
# If needed: brew install openblas lapack
```

**Ubuntu/Debian**:
```bash
sudo apt-get install libblas-dev liblapack-dev
```

**Fedora/RHEL**:
```bash
sudo dnf install blas-devel lapack-devel
```

## Testing

### Running Tests

```bash
# Run all tests
stack test

# Run with verbose output
stack test --test-arguments "--format=progress"

# Run specific test module
stack test --test-arguments "--match AdamSpec"
```

### Test Coverage

The test suite includes:

- **Unit Tests**: Individual component testing
- **Integration Tests**: End-to-end workflow testing
- **Property Tests**: QuickCheck for mathematical properties

### Test Modules

- `AdamSpec`: Optimizer initialization, updates, convergence
- `VocabSpec`: Encoding, decoding, bidirectional consistency
- `EmbeddingsSpec`: Token/positional embeddings, forward/backward passes
- `SelfAttentionSpec`: Attention computation, softmax normalization
- `FeedForwardSpec`: ReLU activation, gradient computation
- `LayerNormSpec`: Normalization correctness, learnable parameters
- `TransformerSpec`: Integrated block functionality, residual connections
- `OutputProjectionSpec`: Logit computation, gradient updates
- `LLMSpec`: Tokenization, prediction, training loop
- `DatasetSpec`: JSON/CSV loading, error handling

## Learning Resources

### Understanding Transformers

- **"Attention Is All You Need"** (Vaswani et al., 2017): Original transformer paper
  - https://arxiv.org/abs/1706.03762

- **The Illustrated Transformer** by Jay Alammar
  - https://jalammar.github.io/illustrated-transformer/

- **The Annotated Transformer** by Harvard NLP
  - http://nlp.seas.harvard.edu/annotated-transformer/

### Haskell and Machine Learning

- **"Learn You a Haskell for Great Good!"** by Miran Lipovača
  - http://learnyouahaskell.com/

- **"Real World Haskell"** by Bryan O'Sullivan, Don Stewart, and John Goerzen
  - http://book.realworldhaskell.org/

- **Haskell Matrix Libraries**:
  - hmatrix documentation: https://hackage.haskell.org/package/hmatrix
  - Linear algebra in Haskell: https://wiki.haskell.org/Numeric_Haskell:_A_Vector_Tutorial

### Neural Networks and Deep Learning

- **"Neural Networks and Deep Learning"** by Michael Nielsen
  - http://neuralnetworksanddeeplearning.com/

- **"Deep Learning"** by Goodfellow, Bengio, and Courville
  - https://www.deeplearningbook.org/

- **Stanford CS224N: Natural Language Processing with Deep Learning**
  - https://web.stanford.edu/class/cs224n/

### Optimization Algorithms

- **"Adam: A Method for Stochastic Optimization"** (Kingma & Ba, 2014)
  - https://arxiv.org/abs/1412.6980

## Performance Considerations

### Memory Usage

- Model parameters: ~500K-1M parameters depending on vocabulary size
- Training memory: ~2-4GB RAM recommended
- Inference memory: ~500MB-1GB

### Training Time

On a modern CPU:
- Pre-training (100 epochs): ~10-30 minutes
- Instruction tuning (100 epochs): ~5-15 minutes
- Total training time: ~15-45 minutes

### Optimization Tips

1. **Use optimized BLAS**: Ensure hmatrix uses OpenBLAS or MKL
2. **Compile with -O2**: Already enabled in package.yaml
3. **Reduce vocabulary size**: Smaller vocabulary = faster training
4. **Adjust epochs**: Fewer epochs for faster experimentation

## Troubleshooting

### Common Issues

**Issue**: `hmatrix` installation fails
- **Solution**: Install BLAS/LAPACK development libraries (see Dependencies section)

**Issue**: Out of memory during training
- **Solution**: Reduce vocabulary size or sequence length in `Types.hs`

**Issue**: Training loss not decreasing
- **Solution**: Check learning rate, increase epochs, or verify training data format

**Issue**: Model produces gibberish
- **Solution**: Ensure sufficient training data and epochs; check vocabulary coverage

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `stack test`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **RustGPT**: This project is a Haskell port of [RustGPT](https://github.com/username/RustGPT)
- **Transformer Architecture**: Based on "Attention Is All You Need" (Vaswani et al., 2017)
- **Haskell Community**: For excellent libraries and documentation
- **hmatrix**: For efficient matrix operations in Haskell

## Citation

If you use HaskellGPT in your research or project, please cite:

```bibtex
@software{haskellgpt2025,
  title = {HaskellGPT: A Transformer-based Language Model in Pure Haskell},
  author = {HaskellGPT Team},
  year = {2025},
  url = {https://github.com/username/HaskellGPT}
}
```

## Contact

For questions or feedback:
- GitHub Issues: https://github.com/username/HaskellGPT/issues
- Email: haskellgpt@example.com

---

**Note**: This is an educational project demonstrating functional programming principles in deep learning. For production use cases, consider established frameworks like PyTorch or TensorFlow.
