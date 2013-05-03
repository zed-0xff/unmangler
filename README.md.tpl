# Unmangler

Unmangles mangled C++/Delphi names

## Installation

Add this line to your application's Gemfile:

    gem 'unmangler'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install unmangler

## Usage

### Full unmangle #1
```ruby
  puts Unmangler.unmangle "@afunc$qxzcupi"
```

### Name-only unmangle #1
```ruby
  puts Unmangler.unmangle "@afunc$qxzcupi", :args => false
```

### Full unmangle #2
```ruby
  puts Unmangler.unmangle "@Forms@TApplication@SetTitle$qqrx17System@AnsiString"
```

### Name-only unmangle #2
```ruby
  puts Unmangler.unmangle "@Forms@TApplication@SetTitle$qqrx17System@AnsiString", :args => false
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
