# noeq53-rb

noeq53-rb is a [noeqd](https://github.com/shopify/noeq53) GUID client in Ruby.

## Installation

```
gem install noeq53
```

## Usage

### One-time GUID from localhost

```ruby
require 'noeq53'
Noeq53.generate(2) #=> [75774574592, 75774574608]
```

### Regular usage

```ruby
require 'noeq53'

noeq = Noeq53.new('idserver.local')
noeq.generate #=> 75759828992
noeq.generate(5) #=> [75768020992, 75768021008, 75768021024, 75768021040, 75768021056]
```

