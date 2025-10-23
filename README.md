# Empirical

> (_adjective_) based on what is experienced or seen rather than on theory  
> (_noun_) enhancements for Ruby with a runtime type system

Empirical helps you prevent bugs and make your code self-documenting by enhancing Ruby with a rich and beautiful runtime type system (see [below](#runtime-typing)).

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
