# IO::Watch

Monitor the file-system for changes.

[![Development Status](https://github.com/socketry/io-watch/workflows/Test/badge.svg)](https://github.com/socketry/io-watch/actions?workflow=Test)

## Motivation

Previously, I was using the `listen` gem in combination with `rb-inotify` or `rb-fsevent` to watch for file-system changes. However, those libraries have been around for an extremely long time and have accumulated a lot of cruft. In addition, I don't like having to multiplex in application code depending on the underlying platform. I created this library to provide a simple, unified interface for watching directories for changes. This is the most consistently supported behaviour across all platforms, and fits the needs of most applications without a huge amount of complexity.

## Usage

Please see the [project documentation](https://socketry.github.io/io-watch/) for more details.

  - [Getting Started](https://socketry.github.io/io-watch/guides/getting-started/index) - This guide explains how to use the `io-watch` gem for watching files and directories for changes.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
