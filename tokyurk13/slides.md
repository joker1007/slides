# How to extend TracePoint

## TokyuRuby会議13
## @joker1007

---

# 私はTracePointが好きだ

---

# 今回はTracePoint自体を拡張する話

---

# TracePointはメソッドの呼び出しとreturnをフックできる
# そしてreturnは戻り値が取れる `TracePoint#return_value`

---

# しかし、callされた時の引数が取れない

Rubyレベルのメソッドの場合は以下を駆使すれば取ろうと思えば取れる。

- `TracePoint#binding`
- `Binding#local_variable_get`
- `Method#parameters`

しかし、Cで実装されたものはどうやっても取得できない。
Cで実装されたメソッドはマッピングされたCの関数を呼んでるだけで、引数名もbindingもない。

---

# 納得いかないので取れる様にしてみた

---

# DEMO

---

# 時間切れまでどうやったかを話す

---

# 最初に

- `-O0`でコンパイルしたRubyを用意する
- 簡単な機能だけでも`gdb`を使える様になっておく

正直gdbで止めて追っかけないと、相当詳しくない限りVMの処理を追うのは難しい。

---

# そもそもTracePointとは

`vm_trace.c`に実装がある。

- `rb_tp_t`という構造体が情報を保持している
- `enable`を呼ぶとvmポインタを辿って`global_event_hooks`という箇所にhook処理を登録する
- 各イベントに対応した箇所に`EXEC_EVENT_HOOK`というマクロがあり、有効なhook処理があればそこからhookが実行される

---

# 修正箇所の探し方

TracePointの各イベントは`RUBY_EVENT_<name>`という形式で表現されている。
修正したい対象のeventでgrepすればすぐに見つかる。
今回のターゲットは`RUBY_EVENT_C_CALL`と`RUBY_EVENT_CALL`。

---

# :c_call の実行場所

`vm_insnhelper.c`の`vm_call_cfunc_with_frame`にある。

```c
static VALUE
vm_call_cfunc_with_frame(rb_execution_context_t *ec, rb_control_frame_t *reg_cfp, struct rb_calling_info *calling, const struct rb_call_info *ci, struct rb_call_cache *cc)
{
    VALUE val;
    const rb_callable_method_entry_t *me = cc->me;
    const rb_method_cfunc_t *cfunc = vm_method_cfunc_entry(me);
    int len = cfunc->argc;

    VALUE recv = calling->recv;
    VALUE block_handler = calling->block_handler;
    int argc = calling->argc;

    RUBY_DTRACE_CMETHOD_ENTRY_HOOK(ec, me->owner, me->def->original_id);
    EXEC_EVENT_HOOK(ec, RUBY_EVENT_C_CALL, recv, me->def->original_id, ci->mid, me->owner, Qundef);

    vm_push_frame(ec, NULL, VM_FRAME_MAGIC_CFUNC | VM_FRAME_FLAG_CFRAME | VM_ENV_FLAG_LOCAL, recv,
		  block_handler, (VALUE)me,
		  0, ec->cfp->sp, 0, 0);

    if (len >= 0) rb_check_arity(argc, len, len);

    reg_cfp->sp -= argc + 1;
    val = (*cfunc->invoker)(recv, argc, reg_cfp->sp + 1, cfunc->func);

    CHECK_CFP_CONSISTENCY("vm_call_cfunc");

    rb_vm_pop_frame(ec);

    EXEC_EVENT_HOOK(ec, RUBY_EVENT_C_RETURN, recv, me->def->original_id, ci->mid, me->owner, val);
    RUBY_DTRACE_CMETHOD_RETURN_HOOK(ec, me->owner, me->def->original_id);

    return val;
}
```

---


# 引数はどこか

```c
val = (*cfunc->invoker)(recv, argc, reg_cfp->sp + 1, cfunc->func);
```

実際のC関数を呼び出す処理はここ。
`val`は戻り値であり、`RUBY_EVENT_C_RETURN`に付随データとして渡されている。
引数にあたるのは`reg_cfp->sp + 1`。ここに引数情報がある。

---

# spって？

多分、スタックポインタの略。
RubyVMはスタックマシンであり、大体以下の様な仕組みで動作している。

- スタックにオブジェクトを積む
- ISeqを取得する
- ISeqに対応した数だけスタックからオブジェクトをpopして命令を実行する
- 戻り値をスタックに積む

これを延々繰り返す。
spは`VALUE`のポインタであり、つまりRubyのスタックはオブジェクトとして表現可能なものが連なった単なる連続したメモリ領域である。

---

# Rubyにおけるメソッド実行

改めてISeqを確認する。

```ruby
String.new("hoge")
```

```
% ruby --dump=insns tokyu_experiment3.rb
== disasm: #<ISeq:<main>@tokyu_experiment3.rb:1 (1,0)-(1,18)> (catch: FALSE)
0000 opt_getinlinecache           7, <is:0>                           (   1)[Li]
0003 getconstant                  :String
0005 opt_setinlinecache           <is:0>
0007 putstring                    "hoge"
0009 opt_send_without_block       <callinfo!mid:new, argc:1, ARGS_SIMPLE>, <callcache>
0012 leave
```

ISeqのsend命令のバリエーションでメソッドが呼び出される。
`opt_send_without_block`の直前の`putstring`に注目。これが引数。
その上にある`getconstant :String`がレシーバ。

---

# `vm_call_cfunc_with_frame`を再確認

```c
val = (*cfunc->invoker)(recv, argc, reg_cfp->sp + 1, cfunc->func);
```

sp + 1しているのはレシーバの位置にspがあるからであることが分かる。

---

# TracePointオブジェクトへのデータの受け渡し

`:c_return`の`return_value`を参考にする。

```c
EXEC_EVENT_HOOK(ec, RUBY_EVENT_C_RETURN, recv, me->def->original_id, ci->mid, me->owner, val);
```

最後の引数が`return_value`にあたる。

---

# `TracePoint#return_value`の実装

```c
VALUE
rb_tracearg_return_value(rb_trace_arg_t *trace_arg)
{
    if (trace_arg->event & (RUBY_EVENT_RETURN | RUBY_EVENT_C_RETURN | RUBY_EVENT_B_RETURN)) {
	/* ok */
    }
    else {
	rb_raise(rb_eRuntimeError, "not supported by this event");
    }
    if (trace_arg->data == Qundef) {
        rb_bug("rb_tracearg_return_value: unreachable");
    }
    return trace_arg->data;
}
```

つまり`EXEC_EVENT_HOOK`の最後の引数を使えば`rb_trace_arg_t`の`data`に任意のオブジェクトを渡すことが出来る。

---

# 引数の取り方と、TracePointへの渡し方が分かった
# 後は配列を作って渡すだけ

---

# 最終的なパッチ

```diff
diff --git a/vm_insnhelper.c b/vm_insnhelper.c
index 93b1ebfe7a..471395dc60 100644
--- a/vm_insnhelper.c
+++ b/vm_insnhelper.c
@@ -2200,7 +2200,13 @@ vm_call_cfunc_with_frame(rb_execution_context_t *ec, rb_control_frame_t *reg_cfp
     int argc = calling->argc;

     RUBY_DTRACE_CMETHOD_ENTRY_HOOK(ec, me->owner, me->def->original_id);
-    EXEC_EVENT_HOOK(ec, RUBY_EVENT_C_CALL, recv, me->def->original_id, ci->mid, me->owner, Qundef);
+
+    VALUE argv = Qundef;
+    rb_hook_list_t *global_hooks = rb_vm_global_hooks(ec);
+    if (UNLIKELY(global_hooks->events & (RUBY_EVENT_C_CALL))) {
+       argv = rb_ary_new_from_values(argc, reg_cfp->sp - argc);
+    }
+    EXEC_EVENT_HOOK(ec, RUBY_EVENT_C_CALL, recv, me->def->original_id, ci->mid, me->owner, argv);

     vm_push_frame(ec, NULL, VM_FRAME_MAGIC_CFUNC | VM_FRAME_FLAG_CFRAME | VM_ENV_FLAG_LOCAL, recv,
                  block_handler, (VALUE)me,
```

---

# そして作ってから考えた

---

# ユースケースが思い付かない！

せっかく書いたんだけど、このままではパッチを送るだけの説得力が無い……。
というわけでユースケースを募集しております。

目的と手段が入れ替わるのはプログラミングではよくありますよね。
