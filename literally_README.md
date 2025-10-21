# Literally [WIP]

Literally is a tiny pre-processor for Ruby that lets you write methods with runtime type checking using [Literal](https://www.literal.fun).

Literally uses genuine Ruby syntax but pre-processes it to be interpreted in a different way.

### Return types

You can specify a return type for a method.

```ruby
def say_hello = String do
  "Hello World!"
end
```

This will add a runtime assertion that the return value is a `String`.

> [!NOTE]
> The return value must be specified for Literally to process the method at all. You can always specify that it returns `_Void` or `_Any?`.

### Positional arguments

We use Ruby’s _default_ value for arguments as the place to specify the type.

```ruby
def say_hello(name = String) = String do
  "Hello #{name}!"
end
```

Okay, but how do we specify defaults?

```ruby
def say_hello(name = String {"World"}) = String do
  "Hello #{name}!"
end
```

### Keyword arguments

Keyword arguments work the same way

```ruby
def say_hello(name: String {"World"}) = String do
  "Hello #{name}!"
end
```

### Splats

Splats are typed by using an Array literal

```ruby
def say_hello(names = [String]) = String do
  "Hello #{names.join(", ")}!"
end
```

This is the equivalent to `def say_hello(*names)`. In this context `[String]` makes the `*names` splat and types it as `_Array(String)`.

You don’t need to specify a default because splats always default to an empty Array.

But what if you wanted to use the literal value `[String]` itself as a type? `[String]` is in fact a type that only matches an array that contains the String class.

As you can see

```ruby
[String] === [String]
```

In this case, you can wrap the type in parentheses

```ruby
def say_hello(names = ([String])) = String do
  # the positional argument `names` here must be
  # an array with the class `String` and nothing else inside it.
end
```

### Keyword splats

Keyword splats are the same but using a Hash literal to specify K/V types. In this context, `{String => String}` makes the `**greetings` keyword splat and types it as `_Hash(String, String)`.

```ruby
def say_hello(greetings: {String => String}) = String do
  greetings.map do |greeting, name|
    "#{greeting} #{name}"
  end.join("\n")
end
```

Again, defaults don’t need to be specified here because the default will always be an empty Hash.

### Splats with named types

Let’s say you have a type called Position.

```ruby
Position = _Tuple(Integer, Integer, Integer)
```

And you want to accept `*position` as `Position`, you could specify that like this

```ruby
def move_to(position = [*Position]) = _Void do
end
```

Same with keyword arguments and keyword splats

```ruby
Position = _Map(x: Integer, y: Integer, z: Integer)
```

```ruby
def move_to(position: {**Position}) = _Void do
end
```

### Blocks

Blocks are always optional and always Procs so there’s no reason to type them. If you want to require a block, we recommend adding `raise unless block_given?` to your method.
