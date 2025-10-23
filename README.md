# Empirical

Empirical pre-processes your code so that, automatically:

1. instance variable reads are guarded against undefined,
2. you can define type checked method definitions via the `fun` keyword (instead of `def`), and
3. you can define class/module defined callbacks via the `class_defined`/`module_defined` methods

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
