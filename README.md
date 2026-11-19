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

It gives you four things in the files you opt in:

1. [Typed methods](#typed-methods) with `fun`.
2. [Strict instance variables](#strict-instance-variables): reading an undefined ivar raises instead of returning `nil`.
3. [Typed instance variables](#typed-instance-variables): every ivar you write is declared with `var` and checked.
4. [Definition hooks](#definition-hooks): `defined`, `reopened` and `redefined` run when a class body closes.

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

You can pass an array of globs to `Empirical.init` as `include:` and `exclude:`. They match as they would in `Dir.glob`, so `**/` matches any number of directories, including none.

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

### Introspection

`Method` and `UnboundMethod` have `parameter_types` and `return_type`. Untyped parameters are left out, and both return `nil` for methods not defined with `fun`.

```ruby
fun create(name = String, tags = [Symbol], admin?: _Boolean) => User do
  # ...
end

method(:create).parameter_types # => { name: String, tags: _Array(Symbol), admin: _Nilable(_Boolean) }
method(:create).return_type     # => User
```

A `void` method’s return type is `_Void`, a `never` method’s is `_Never`, and an `itself` method’s is `Empirical::Itself`.

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

Every instance variable your code writes must be declared with `var`, which gives it a type. Every write is checked, wherever it happens: in the class, in a subclass, or through a writer.

```ruby
class User
  var name: String, admin: _Boolean

  attr_reader :name

  def initialize(name)
    @name = name   # checked
    @admin = false # checked
  end
end

User.new(1) # Empirical::TypeError: Instance variable @name assigned the wrong type.
```

`var` only declares. Use `attr_reader`, `attr_writer` and `attr_accessor` for accessors; writers are checked too.

Writing an ivar that hasn’t been declared raises an `Empirical::UndeclaredInstanceVariableError`, which also catches typos.

```ruby
def rename(name)
  @nmae = name # Undeclared instance variable `@nmae` on an instance of User. Declare it with `var nmae: Type`.
end
```

This applies to your code, in the files you include. Libraries can still set whatever ivars they like on your objects.

If you don’t want to constrain an ivar, declare it as `_Any?`. Literal’s `_Any` is anything except `nil`.

```ruby
var cache: _Any?
```

Modules declare the ivars they write in the same way. A subclass inherits its parent’s declarations and can’t change their types.

Ivars on a class or module itself are declared on its singleton class.

```ruby
class Registry
  class << self
    var entries: Hash
  end

  @entries = {}
end
```

One gap: `instance_variable_set` writes the ivar directly and isn’t checked.

### With Literal

Literal’s `prop` declares its ivar with `var`, then adds the initializer and any accessors. In a `Literal::Struct`, `Literal::Data`, `Literal::Object`, or any class that extends `Literal::Properties`, writes inside your own methods are checked against the prop’s type.

```ruby
class Person < Literal::Struct
  prop :name, String
  var nickname: _Nilable(String)

  def rename(name)
    @name = name # checked by Empirical
  end
end
```

Use `prop` for what the object is made from and `var` for state it keeps.

## Definition hooks

Ruby tells a class when it is inherited, but that happens before the subclass has a body. Empirical adds three hooks that run when a class or module body closes, after everything in it has been defined.

| Hook | Runs when |
|---|---|
| `defined` | The body closes for the first time |
| `reopened` | The body of a class or module that was already defined closes again |
| `redefined` | A new class or module takes the name of an earlier one, as happens when code reloads. Calls `defined` unless you override it |

Define them as class methods. Like `inherited`, they are inherited, so a hook on a base class runs for every subclass.

```ruby
class Model
  def self.defined
    super
    validate_schema!
    freeze
  end

  def self.reopened
    raise "#{self} can’t be reopened"
  end
end

class User < Model
  attribute :name
end # Model.defined runs here, with User as self
```

They also run at the end of `Class.new do ... end` and `Module.new do ... end`.

Reopening a class that was defined somewhere Empirical didn’t see, such as a library class, counts as `reopened`.

The hooks only run for class and module bodies in the files you include, and they don’t run if the body raises.

## Checks when a file loads

Some mistakes are visible in the source. Empirical checks those once, when the method or class is defined, so they surface when the file loads instead of when the line eventually runs.

```ruby
fun answer => String do
  42
end
# Empirical::StaticTypeError: app/answer.rb:2: `answer` returns 42, which doesn’t match String.
```

It checks a value whose type it can know from the source, wherever that value meets a declared type:

| Value | Checked against |
|---|---|
| A literal that is returned, including by an early `return` | The return type |
| A literal default in the block parameters | The parameter’s type |
| A literal written to an ivar in an instance method | The declaration in the same class |
| A parameter that is returned and never reassigned | The return type |
| A typed ivar that is returned | The return type |
| A parameter or a typed ivar written to a typed ivar | The declaration in the same class |

Literals are checked with the real type, so this works for any type, such as `_Integer(1..)` or one of your own.

For a parameter or an ivar, only the declared type is known, not the value. Empirical reports those only when the two types can never overlap. An `Integer` returned as a `String` is an error. A `Numeric` returned as an `Integer` is not, because it might be one at runtime, where it is still checked.

```ruby
fun name_of(id = Integer) => String do
  id
end
# app/user.rb:2: `name_of` returns `id`, which is declared as Integer and can never match String.
```

Ivars are checked the same way, because every ivar has a declared type:

```ruby
class Counter
  var count: Integer

  fun label => String do
    @count
  end
end
# app/counter.rb:5: `label` returns `@count`, which is declared as Integer and can never match String.
```

Anything Empirical can’t be sure about is left to the runtime checks.

## How it works

Empirical hooks into `require`. When a matching file loads, it is parsed with Prism and rewritten before Ruby compiles it. A `fun` becomes a `def` with the type checks inlined at the top and a return check at the bottom. Types are evaluated once, where the method is defined.

The rewrite never adds or removes a line, so line numbers in backtraces, debuggers and coverage reports match your source.

Code passed as a string to `eval`, `class_eval`, `module_eval` and `instance_eval` is processed too when the file it’s attributed to matches.

### Known limitations

- Types are stored per place in the source, not per definition. If the same `fun` is evaluated more than once with different types (for example in a class factory that takes the type from a local variable), the last evaluation wins for all of them.
- `Object` includes `Literal::Types`, so the type helpers (`_Array`, `_Nilable`, ...) are available everywhere.
