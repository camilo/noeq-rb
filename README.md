# noeq-rb

noeq-rb is a [noeqd](https://github.com/shopify/noeqd) GUID client in Ruby.

## Installation

```
Add this repo to your Gemfile
```

## Usage

### One-time GUID from localhost

```ruby
require 'noeq'
Noeq.generate(2) #=> [75774574592, 75774574608]
```

### Regular usage

```ruby
require 'noeq'

noeq = Noeq.new('idserver.local')
noeq.generate #=> 75759828992
noeq.generate(5) #=> [75768020992, 75768021008, 75768021024, 75768021040, 75768021056]
```

