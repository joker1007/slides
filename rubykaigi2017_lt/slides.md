<!-- $theme: gaia -->
<!-- template: invert -->

# Use case of Refinements
# With Black Magic
#### Tomohiro Hashidate (@joker1007)

---

# self.inspect
- @joker1007
- Repro inc. CTO
  - Vimmer
  - Ruby/Rails
  - fluentd/embulk
  - Docker/ECS
  - Bigquery/EMR/Hive/Presto

---

# I :heart: Refinements because..

- More safe MonkeyPatch
- Keep method use case in specific domain
- Allow override builtin Classes
- Romantic :innocent:

---

# Introduce some use cases
# of
# Refinements
---

# Case1

## MonkeyPatch to google-api-client

**In past, google-api-client could not `skip_serialization`.**

**It is not efficiently in a case that response data size is enormous, especially Bigquery.**

**Refinements enable to replace serialization implementation in specific context.**
(It is already unnecessary now)

---

```ruby
module QueryEngine::Bigquery
  class SimpleHashRepresentable
    def initialize(instance = {})
      @instance = instance
    end
    def from_json(body, options)
      @instance.merge!(Oj.load(body))
    end
  end
  module HashrizeGetJobQueryResults
    refine Google::Apis::BigqueryV2::BigqueryService do
      def get_job_query_results(*args)
        command = make_simple_command(:get, 'projects/{projectId}/queries/{jobId}', options)
        command.response_representation =
          SimpleHashRepresentable
        command.response_class = Hash        
        # Omit
      end
    end
  end
end
```

---

# Case2
## Concern Module

**We want to send data from application to fluentd**.
**That data consists of various objects.**

**I want to implement some helper methods in those classes.**

**Refinements can implement helper methods that is called in concern module context only.**

---

```ruby
module FluentLoggable
  using(Module.new do
    refine Clip do
      def fluentd_tag
        "fluentd.tag.definition"
      end
      def fluentd_payload
        # constructing payload
      end
      def fluentd_timestamp
        created_at
      end      
      # Other helpers
    end
  end)
  def post_to_fluentd # Publish to external context
    Fluent::Logger.post_with_time(
      fluentd_tag, fluentd_payload, fluentd_timestamp)
  end
end
```

---

# Case3
## DSL

**I implemented this.**

```ruby
def foo
    1 | 2 | 3
    5 | 8 | 13
    0 | 0 | 0
end
foo #=> Like [[1,2,3], [5,8,13], [0,0,0]] objects
```
**By Refinements**
**How?**

---

## binding_ninja
- **this gem passes binding of method caller implicity**
- **Lightweight replacement of binding_of_caller**

```ruby
class Foo
  extend BindingNinja
  def foo(binding, arg)
    p binding
    p arg
  end
  auto_inject_binding :foo
end

Foo.new.foo(1) 
# => <Binding of toplevel>
# => 1
```

---

## binding_ninja impl

```c
static VALUE
auto_inject_binding_invoke(int argc,VALUE *argv,VALUE self)
{
  VALUE binding, args_ary;

  binding = rb_binding_new(); // Important
  args_ary = rb_ary_new_from_values(argc, argv);
  rb_ary_unshift(args_ary, binding);

  return rb_call_super(argc+1, RARRAY_CONST_PTR(args_ary));
}
```

Create binding in C method call, returns caller context binding.
Because Ruby level `cfp` is not changed.

---

**And create and prepend module in C method call to wrap any methods.**

```c
    mod_name = rb_mod_name(mod);
    extensions = rb_ivar_get(rb_mBindingNinja,
      rb_intern("@auto_inject_binding_extensions"));
    ext_mod = rb_hash_aref(extensions, mod_name);
    if (ext_mod == Qnil) {
      ext_mod = rb_module_new();
      rb_hash_aset(extensions, mod_name, ext_mod);
    }
    if (rb_mod_include_p(mod, ext_mod) == Qfalse) {
      rb_prepend_module(mod, ext_mod);
    }

    rb_define_method_id(ext_mod, SYM2ID(method_sym),
      auto_inject_binding_invoke, -1);
```

---

#### Back to Table Syntax DSL

```ruby
module TableSyntaxImplement
  extend BindingNinja
  auto_inject_binding def |(b, other) # Wrap method
    caller = b.receiver
    # Define instance variable in caller context!
    if caller.instance_variable_defined?(:@__table)
      table = caller.instance_variable_get(:@__table)
    else
      table = Table.new
      caller.instance_variable_set(:@__table, table)
    end
    row = Table::Row.new(self)
    table.add_row(row); row.add_param(other)
    table
  end
end
```

And `refine` Builtin classes. `String`, `Integer`, `Nil` etc. 

---

# This DSL is used by
# rspec-parameterized

---

```ruby
describe "plus" do
  using RSpec::Parameterized::TableSyntax

  where(:a, :b, :answer) do
    1 | 2 | 3
    5 | 8 | 13
    0 | 0 | 0
  end

  with_them do
    it "should do additions" do
      expect(a + b).to eq answer
    end
  end
end
```

RSpec ExampleGroup is actual Class definition.
It is Refinements friendly :heart:

---

# Refinements is fun :laughing:
# Shall we use Refinements?
# Thanks!!