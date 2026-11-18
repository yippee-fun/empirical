# Empirical

> (_adjective_) based on what is experienced or seen rather than on theory \
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

It gives you three things in the files you opt in:

1. [Typed methods](#typed-methods) with `fun`.
2. [Strict instance variables](#strict-instance-variables): reading an undefined ivar raises instead of returning `nil`.
3. [Typed instance variables](#typed-instance-variables): every ivar you write is declared with `prop` and checked.

Types are [Literal](https://literal.fun) types. Anything that responds to `===` works: classes, ranges, procs, and Literal’s generics like `_Array(String)` or `_Nilable(Integer)`.

## Setup

Empirical needs Ruby 3.4 or later.

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

Only files that match are processed, and only when they are loaded after `Empirical.init`.

## Typed methods

A `fun` is a `def` with types. The signature comes first, then `=>` and the return type, then a `do ... end` body.

```ruby
fun greet(name = String) => String do
  "Hello #{name}"
end
```

Calling it with the wrong type, or returning the wrong type, raises an `Empirical::TypeError`.

### Parameters

Each parameter keeps the shape it would have in a `def`. You write the type where the default would go.

| You write | You get | Meaning |
|---|---|---|
| `name = String` | `name` | Positional |
| `name: String` | `name:` | Keyword |
| `name?: String` | `name: nil` | Optional keyword, `nil` when omitted |
| `names = [String]` | `*names` | Positional splat, each element a `String` |
| `options: { Symbol => String }` | `**options` | Keyword splat with typed keys and values |
| `*args`, `**kwargs`, `&block` | unchanged | Untyped, for passing straight through |

```ruby
fun create(name = String, tags = [Symbol], admin?: _Boolean, &block) => User do
  # def create(name, *tags, admin: nil, &block)
end
```

### Defaults

Because the type sits where a default would, defaults go in the block parameters. They are always written as keywords, even for positional parameters.

```ruby
fun greet(name = String, punctuation: String) => String do |name: "World", punctuation: "!"|
  "Hello #{name}#{punctuation}"
end

greet                         # => "Hello World!"
greet("Joel", punctuation: "?") # => "Hello Joel?"
```

A default is type checked like any other value. For an optional positional parameter, make the type nilable and default it to `nil`.

```ruby
fun greet(name = _Nilable(String)) => String do |name: nil|
  name ? "Hello #{name}" : "Hello"
end
```

Ruby only allows simple expressions in block parameter defaults, so wrap anything with an operator in parentheses: `|total: (price * 2)|`.

### Return types

Any type works as a return type. Early returns are checked too. There are three special ones:

- `void` means the return value shouldn’t be used. The method returns an object that raises if you call anything on it, and `return value` is a compile-time error.
- `never` means the method doesn’t return, because it always raises or loops forever. Returning raises an `Empirical::NeverError`.
- `itself` means the method returns the object it was called on. Returning any other object, even one of the same class, raises an `Empirical::TypeError`.

```ruby
fun log(message = String) => void do
  puts message
end

fun fail!(message = String) => never do
  raise Error, message
end

fun add(item = Item) => itself do
  @items << item
  self
end
```

Types are evaluated where the method is defined, so `self` as a return type means the class, and any instance of it would pass. Use `itself` when it has to be the same object.

### Visibility, singleton methods, blocks

```ruby
private fun secret => String do
  "..."
end

fun self.build(name: String) => User do
  new(name)
end

fun each_name => void do
  @names.each { |name| yield name }
end
```

`rescue` and `ensure` work in the body just as they do in a `def`.

### What `fun` can’t do

Use a plain `def` for these.

- Setters (`name=`) and operators (`==`, `[]`, `+`).
- A `{ ... }` body. It must be `do ... end`.
- `it` and numbered parameters in the body.

Mistakes in a signature are reported when the file loads, with the path and line.

```
app/models/user.rb:12: The default for `nmae` doesn’t match a positional or keyword parameter in the signature.
```

## Strict instance variables

Reading an instance variable that hasn’t been set raises an `Empirical::NameError` instead of quietly returning `nil`.

```ruby
def name
  @nmae # Empirical::NameError: Undefined instance variable `@nmae`. Did you mean `@name`?
end
```

`defined?(@name)` and `@name ||= value` are still allowed, so memoization works as usual.

## Typed instance variables

Every instance variable your code writes must be declared with `prop`, which gives it a type. Every write is checked, wherever it happens: in the class, in a subclass, or through a writer.

```ruby
class User
  prop :name, String, reader: :public, writer: :public
  prop :admin, _Boolean, predicate: :public

  def initialize(name)
    @name = name   # checked
    @admin = false # checked
  end
end

User.new(1) # Empirical::TypeError: Instance variable @name assigned the wrong type.
```

`reader:`, `writer:` and `predicate:` each take `:public`, `:protected` or `:private`.

Writing an ivar that hasn’t been declared raises an `Empirical::UndeclaredInstanceVariableError`, which also catches typos.

```ruby
def rename(name)
  @nmae = name # Undeclared instance variable `@nmae` on an instance of User. Declare it with `prop :nmae, Type`.
end
```

This applies to your code, in the files you include. Libraries can still set whatever ivars they like on your objects.

If you don’t want to constrain an ivar, declare it as `_Any`.

```ruby
prop :cache, _Any
```

Modules declare the ivars they write in the same way. A subclass inherits its parent’s props and can’t change their types.

Ivars on a class or module itself are declared on its singleton class.

```ruby
class Registry
  class << self
    prop :entries, Hash
  end

  @entries = {}
end
```

`attr_writer` and `attr_accessor` are checked too, so you can keep using them alongside `prop`.

```ruby
class User
  prop :name, String
  attr_accessor :name
end

User.new.name = 1 # Empirical::TypeError
```

One gap: `instance_variable_set` writes the ivar directly and isn’t checked.

## How it works

Empirical hooks into `require`. When a matching file loads, it is parsed with Prism and rewritten before Ruby compiles it. A `fun` becomes a `def` with the type checks inlined at the top and a return check at the bottom. Types are evaluated once, where the method is defined.

The rewrite never adds or removes a line, so line numbers in backtraces, debuggers and coverage reports match your source.

Code passed as a string to `eval`, `class_eval`, `module_eval` and `instance_eval` is processed too when the file it’s attributed to matches.

### Known limitations

- Types are stored per place in the source, not per definition. If the same `fun` is evaluated more than once with different types (for example in a class factory that takes the type from a local variable), the last evaluation wins for all of them.
- `Object` includes `Literal::Types`, so the type helpers (`_Array`, `_Nilable`, ...) are available everywhere.
