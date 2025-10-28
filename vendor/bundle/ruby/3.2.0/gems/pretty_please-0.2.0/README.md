## PrettyPlease - Pretty Print Ruby objects as Ruby

PrettyPlease is a pretty-printing library for Ruby that formats objects in a readable and structured way.

PrettyPlease ensures the output is **valid Ruby code**, making it human, machine, and [diff](https://github.com/joeldrapper/difftastic-ruby)-friendly.

> [!NOTE]
> PrettyPlease is used and was extracted from [`difftastic-ruby`](https://github.com/joeldrapper/difftastic-ruby).

### Installation

Install the gem and add it to the application's `Gemfile` by executing:

```shell
bundle add pretty_please
```

If bundler is not being used to manage dependencies, install the gem by executing:

```shell
gem install pretty_please
```

### Usage

`PrettyPlease.print(object)` prints the object with ANSI highlighting.

The `PrettyPlease.prettify` method provides a structured and human-readable representation of Ruby objects by outputting valid Ruby code.

It handles a variety of data types including Hashes, Arrays, Sets, Modules, and user-defined objects.

#### Basic Usage

```ruby
require "pretty_please"

puts PrettyPlease.prettify({ a: 1, b: [2, 3], c: { d: 4 } })
```

**Output:**

```ruby
{
  a: 1,
  b: [2, 3],
  c: { d: 4 },
}
```

**Options:**

- `object`: (required) – The object to prettify and format.
- `tab_width`: 2 (Integer) – The number of spaces (or tabs) per indentation level.
- `max_width`: 60 (Integer) – The maximum width before elements are split into multiple lines.
- `max_depth`: 5 (Integer) – The maximum depth of nested structures before truncation.
- `max_items`: 10 (Integer) – The maximum number of instance variables to display for objects.

### Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Contributing

> [!WARNING]
> Object diffs in `assert_equal` test output are self-hosted. That means if you mess up the output, the tests might not tell you since they are driven by the output. Most of the tests use `assert_equal_ruby`, which is not driven by PrettyPlease.

Bug reports and pull requests are welcome on GitHub at https://github.com/joeldrapper/pretty_please. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/joeldrapper/pretty_please/blob/main/CODE_OF_CONDUCT.md).

### Code of Conduct

Everyone interacting in the `PrettyPlease` project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/joeldrapper/pretty_please/blob/main/CODE_OF_CONDUCT.md).
