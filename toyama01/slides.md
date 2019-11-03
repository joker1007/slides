---
class: invert
style: |
  section.larger h1 {
    font-size: 120px;
  }
  h1 {
    font-size: 56px;
  }
  section {
    font-size: 34px;
  }
---

# TracePointから学ぶRubyVM

## 富山Ruby会議01
## @joker1007

---

# self.inspect

- @joker1007
- Repro inc. CTO
- TracePoint芸人
- 最近はKafkaを触っている
- 最近肺炎に罹って死にそうになってた

---

![repro_logo.png](./repro_logo.png)

様々な領域のエンジニアを絶賛募集中です。

---

# またTracePointか

```
やあ （´・ω・｀)
ようこそ、プレモルハウスへ。
このプレモルはサービスだから、まず飲んで落ち着いて欲しい。

うん、「また」なんだ。済まない。
仏の顔もって言うしね、謝って許してもらおうとも思っていない。

でも、この発表を見たとき、君は、きっと言葉では言い表せない
「ときめき」みたいなものを感じてくれたと思う。
殺伐とした世の中で、そういう気持ちを忘れないで欲しい
そう思って、この資料を作ったんだ。

じゃあ、注文を聞こうか。
```

---

# 突然ですが
# RubyKaigiというイベントがある

- 世界最大級のRubyのテックカンファレンス
- 異様に技術的にハードコアなトーク多数
- Ruby処理系の内部実装の話も多い
- 次回は松本開催

余りにテック度が高いので、良く分からんが何か凄そう、みたいなのを楽しめる。
でも、Rubyの深い部分の話が分かるともっと楽しめる！

---

# RubyVMについて学んでみよう

いきなり目的なく読むのはしんどいので、自分の興味がある機能を取っかかりに。

自分の場合はTracePointから色々追いかけたので、その一例を紹介します。

---

# 最初に

自分でもRubyVMの動きを調べてみようと思う方へ

- `-O0`でコンパイルしたRubyを用意する
  - `./configure --prefix=${INSTALL_DIR} optflags="-O0"`
- 簡単な機能だけでも`gdb`を使える様になっておく

正直gdbで止めて追っかけないと、相当詳しくない限りVMの処理を追うのは難しい。

---

# そもそもTracePointとは

`vm_trace.c`に実装がある。

- `rb_tp_t`という構造体が情報を保持している
- `enable`を呼ぶとvmポインタを辿って`global_event_hooks`という箇所にhook処理を登録する
- 各イベントに対応した箇所に`EXEC_EVENT_HOOK`というマクロがあり、有効なhook処理があればそこからhookが実行される

---

# ソースコードを見てみる

---

# :callと:returnに注目してみる

## TracePointはメソッドの呼び出しとreturnをフックできる
## そしてreturnは戻り値が取れる `TracePoint#return_value`

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

# TracePointを弄るためにはRubyVMの動作の仕組みを知る必要があった

Rubyにおいて引数はどう扱われているのか
スタックVMとはどういうものか

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
reg_cfp->sp -= argc + 1;
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

# send命令とは

ISeqの命令の定義はinsns.defというファイルにある。

```c
/* invoke method. */
DEFINE_INSN
send
(CALL_INFO ci, CALL_CACHE cc, ISEQ blockiseq)
(...)
(VALUE val)
// attr rb_snum_t sp_inc = sp_inc_of_sendish(ci);
{
    VALUE bh = vm_caller_setup_arg_block(ec, GET_CFP(), ci, blockiseq, false);
    val = vm_sendish(ec, GET_CFP(), ci, cc, bh, vm_search_method_wrap);

    if (val == Qundef) {
        RESTORE_REGS();
        NEXT_INSN();
    }
}
```

`vm_sendish` -> `vm_call_general`に繋がりメソッド呼び出しが実行される。

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

# :callイベントの場合

Rubyのメソッド定義は`def`と`define_method`で定義できる。
実はどちらで定義されたかによって呼び出しパスが異なる。

多分、`define_method`だとスコープが切り替わらないからだと思う。

`def`で定義されたメソッドの呼び出しは少し分かりにくい。
実行するISeqを切り替えてVMの実行ループを回しているだけなので、分かりやすい関数が無い。

---

# `def`の場合

`trace_xxx`というiseqの命令が`vm_trace`関数を実行する。
最終的に`vm_insnhelper.c`の`vm_trace_hook`がhookを処理する。

```c
static inline void
vm_trace_hook(rb_execution_context_t *ec, rb_control_frame_t *reg_cfp, const VALUE *pc,
              rb_event_flag_t pc_events, rb_event_flag_t target_event,
              rb_hook_list_t *global_hooks, rb_hook_list_t *local_hooks, VALUE val)
{
    rb_event_flag_t event = pc_events & target_event;
    VALUE self = GET_SELF();

    VM_ASSERT(rb_popcount64((uint64_t)event) == 1);

    if (event & global_hooks->events) {
        /* increment PC because source line is calculated with PC-1 */
        reg_cfp->pc++;
        vm_dtrace(event, ec);
        rb_exec_event_hook_orig(ec, global_hooks, event, self, 0, 0, 0 , val, 0);
        reg_cfp->pc--;
    }

    if (local_hooks != NULL) {
        if (event & local_hooks->events) {
            /* increment PC because source line is calculated with PC-1 */
            reg_cfp->pc++;
            rb_exec_event_hook_orig(ec, local_hooks, event, self, 0, 0, 0 , val, 0);
            reg_cfp->pc--;
        }
    }
}
```

---

# メソッドの引数のISeq表現

```ruby
def hoge(i)
  puts "hoge #{i}"
end
```

```
== disasm: #<ISeq:hoge@trace_args.rb:1 (1,0)-(3,3)> (catch: FALSE)
local table (size: 1, argc: 1 [opts: 0, rest: -1, post: 0, block: -1, kw: -1@-1, kwrest: -1])
[ 1] i@0<Arg>
0000 putself                                                          (   2)[LiCa]
0001 putobject                    "hoge "
0003 getlocal_WC_0                i@0
0005 dup
0006 checktype                    T_STRING
0008 branchif                     15
0010 dup
0011 opt_send_without_block       <callinfo!mid:to_s, argc:0, FCALL|ARGS_SIMPLE>, <callcache>
0014 tostring
0015 concatstrings                2
0017 opt_send_without_block       <callinfo!mid:puts, argc:1, FCALL|ARGS_SIMPLE>, <callcache>
0020 leave                                                            (   3)[Re]
```

---

# getlocal命令

```c
DEFINE_INSN
getlocal
(lindex_t idx, rb_num_t level)
()
(VALUE val)
{
    val = *(vm_get_ep(GET_EP(), level) - idx);
    RB_DEBUG_COUNTER_INC(lvar_get);
    (void)RB_DEBUG_COUNTER_INC_IF(lvar_get_dynamic, level > 0);
}
```

epは多分env pointerだと思う。

---

# epから引数を取得

```diff
diff --git a/vm_insnhelper.c b/vm_insnhelper.c
index 93b1ebfe7a..471395dc60 100644
--- a/vm_insnhelper.c
+++ b/vm_insnhelper.c
@@ -4337,6 +4343,36 @@ vm_trace_hook(rb_execution_context_t *ec, rb_control_frame_t *reg_cfp, const VAL

     VM_ASSERT(rb_popcount64((uint64_t)event) == 1);

+    if (event & (RUBY_EVENT_CALL | RUBY_EVENT_B_CALL)) {
+        const rb_iseq_t *iseq = reg_cfp->iseq;
+        int local_table_size = iseq->body->local_table_size;
+        int not_keyword_arg_size = iseq->body->param.lead_num + iseq->body->param.opt_num + iseq->body->param.flags.has_rest + iseq->body->param.post_num;
+
+        int keyword_size = 0;
+        int keyword_rest = 0;
+        if (iseq->body->param.keyword) {
+            keyword_size = iseq->body->param.keyword->num;
+            keyword_rest = iseq->body->param.keyword->rest_start;
+        }
+
+        val = rb_ary_new_from_values(not_keyword_arg_size, reg_cfp->ep - (local_table_size + 2));
+
+        if (keyword_size > 0) {
+            const VALUE *keyword_args = reg_cfp->ep - (local_table_size + 2) + not_keyword_arg_size;
+            VALUE hash = rb_hash_new();
+            int i;
+            for (i=0; i<keyword_size; i++) {
+                rb_hash_aset(hash, rb_id2sym(*(iseq->body->param.keyword->table + i)), *(keyword_args + i));
+            }
+            rb_ary_push(val, hash);
+        }
+
+        if (keyword_rest > 0) {
+            const VALUE *keyword_rest = reg_cfp->ep - (local_table_size + 2) + not_keyword_arg_size + keyword_size + 1;
+            rb_ary_push(val, *keyword_rest);
+        }
+    }
+
```

---

# `define_method`の場合

`vm.c`の`invoke_bmethod`でhookを処理している。

```c
static VALUE
invoke_bmethod(rb_execution_context_t *ec, const rb_iseq_t *iseq, VALUE self, const struct rb_captured_block *captured, const rb_callable_method_entry_t *me, VALUE type, int opt_pc)
{
    /* bmethod */
    int arg_size = iseq->body->param.size;
    VALUE ret;
    rb_hook_list_t *hooks;

    VM_ASSERT(me->def->type == VM_METHOD_TYPE_BMETHOD);

    vm_push_frame(ec, iseq, type | VM_FRAME_FLAG_BMETHOD, self,
		  VM_GUARDED_PREV_EP(captured->ep),
		  (VALUE)me,
		  iseq->body->iseq_encoded + opt_pc,
		  ec->cfp->sp + arg_size,
		  iseq->body->local_table_size - arg_size,
		  iseq->body->stack_max);

    RUBY_DTRACE_METHOD_ENTRY_HOOK(ec, me->owner, me->def->original_id);
    EXEC_EVENT_HOOK(ec, RUBY_EVENT_CALL, self, me->def->original_id, me->called_id, me->owner, Qnil);

    if (UNLIKELY((hooks = me->def->body.bmethod.hooks) != NULL) &&
        hooks->events & RUBY_EVENT_CALL) {
        rb_exec_event_hook_orig(ec, hooks, RUBY_EVENT_CALL, self,
                                me->def->original_id, me->called_id, me->owner, Qnil, FALSE);
    }
    VM_ENV_FLAGS_SET(ec->cfp->ep, VM_FRAME_FLAG_FINISH);
    ret = vm_exec(ec, TRUE);

    EXEC_EVENT_HOOK(ec, RUBY_EVENT_RETURN, self, me->def->original_id, me->called_id, me->owner, ret);
    if ((hooks = me->def->body.bmethod.hooks) != NULL &&
        hooks->events & RUBY_EVENT_RETURN) {
        rb_exec_event_hook_orig(ec, hooks, RUBY_EVENT_RETURN, self,
                                me->def->original_id, me->called_id, me->owner, ret, FALSE);
    }
    RUBY_DTRACE_METHOD_RETURN_HOOK(ec, me->owner, me->def->original_id);
    return ret;
}
```

---

spからでも取れるが、直前の関数まで`argv`が渡ってきているので、直接渡せそう。

```diff
diff --git a/vm.c b/vm.c
index 7ad6bdd264..436f0aa4c8 100644
--- a/vm.c
+++ b/vm.c
@@ -1031,7 +1031,7 @@ invoke_block(rb_execution_context_t *ec, const rb_iseq_t *iseq, VALUE self, cons
 }

 static VALUE
-invoke_bmethod(rb_execution_context_t *ec, const rb_iseq_t *iseq, VALUE self, const struct rb_captured_block *captured, const rb_callable_method_entry_t *me, VALUE type, int opt_pc)
+invoke_bmethod(rb_execution_context_t *ec, const rb_iseq_t *iseq, VALUE self, int argc, const VALUE *argv, const struct rb_captured_block *captured, const rb_callable_method_entry_t *me, VALUE type, int opt_pc)
 {
     /* bmethod */
     int arg_size = iseq->body->param.size;
@@ -1049,12 +1049,18 @@ invoke_bmethod(rb_execution_context_t *ec, const rb_iseq_t *iseq, VALUE self, co
                  iseq->body->stack_max);

     RUBY_DTRACE_METHOD_ENTRY_HOOK(ec, me->owner, me->def->original_id);
-    EXEC_EVENT_HOOK(ec, RUBY_EVENT_CALL, self, me->def->original_id, me->called_id, me->owner, Qnil);
+
+    VALUE data = Qundef;
+    rb_hook_list_t *global_hooks = rb_vm_global_hooks(ec);
+    if (UNLIKELY(global_hooks->events & (RUBY_EVENT_CALL))) {
+       data = rb_ary_new_from_values(argc, argv);
+    }
+    EXEC_EVENT_HOOK(ec, RUBY_EVENT_CALL, self, me->def->original_id, me->called_id, me->owner, data);

     if (UNLIKELY((hooks = me->def->body.bmethod.hooks) != NULL) &&
         hooks->events & RUBY_EVENT_CALL) {
         rb_exec_event_hook_orig(ec, hooks, RUBY_EVENT_CALL, self,
-                                me->def->original_id, me->called_id, me->owner, Qnil, FALSE);
+                                me->def->original_id, me->called_id, me->owner, data, FALSE);
     }
     VM_ENV_FLAGS_SET(ec->cfp->ep, VM_FRAME_FLAG_FINISH);
     ret = vm_exec(ec, TRUE);
@@ -1102,7 +1108,7 @@ invoke_iseq_block_from_c(rb_execution_context_t *ec, const struct rb_captured_bl
        return invoke_block(ec, iseq, self, captured, cref, type, opt_pc);
     }
     else {
-       return invoke_bmethod(ec, iseq, self, captured, me, type, opt_pc);
+       return invoke_bmethod(ec, iseq, self, argc, argv, captured, me, type, opt_pc);
     }
 }
```

---

# まとめ

- TracePointの処理を深く追いかけることで、RubyVMの挙動をより詳しく知ることができた。
- デバッガで止めてデータをモニタしつつ処理を追いかければ、そこまでCに詳しくなくてもCRubyのコードを読み進めることができる。
- 挙動を何となく理解すれば、RubyKaigiの話にもっと付いていける様になるし、Rubyのディープな話を聞くのがもっと楽しくなる。
