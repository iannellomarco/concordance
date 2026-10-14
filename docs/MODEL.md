# Model download

`scripts/fetch-model.sh` downloads [EverPaper/embeddinggemma-2-coreai](https://huggingface.co/EverPaper/embeddinggemma-2-coreai)
(text + image encoders and its Swift package; the audio encoder is skipped) into `Vendor/`, resuming partial
downloads and verifying every file against the repository's `CHECKSUMS.sha256`. This is a developer convenience;
the app itself downloads its own copy into `~/Library/Application Support/Concordance/Model` at first launch, with
the same checks.

`model/` and the whole `Vendor/` directory are git-ignored; nothing model-sized is committed to this repository.
