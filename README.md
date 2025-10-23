# Empirical

> (_adjective_) based on what is experienced or seen rather than on theory
> (_noun_) enhancements for Ruby with a runtime type system

Empirical catches bugs early and makes your code self-documenting by enhancing Ruby with beautiful syntax to define runtime type assertions.

```ruby
fun word_frequency(text: String) => _Hash(String, Integer) do
  text
    .downcase
    .scan(/\w+/)
    .tally
    .sort_by { |word, count| -count }
    .first(10)
    .to_h
end
```

(see [below](#runtime-typing)).

## Setup

Install the gem by adding it to your <kbd>Gemfile</kbd> and running <kbd>bundle install</kbd>. You’ll probably want to set it to `require: false` here because you should require it manually at precisely the right moment.

```ruby
gem "empirical", require: false
```

Now the gem is installed, you should require and initialize the gem as early as possible in your boot process. Ideally, this should be right after Bootsnap is set up. In Rails, this will be in your `boot.rb` file.

```ruby
require "empirical"
```

You can pass an array of globs to `Empirical.init` as `include:` and `exclude:`

```ruby
Empirical.init(include: ["#{Dir.pwd}/**/*"], exclude: ["#{Dir.pwd}/vendor/**/*"])
```
