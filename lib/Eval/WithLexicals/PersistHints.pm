# XXX: Calls for traits really; there's not a MooX::... (yet)
package Eval::WithLexicals::PersistHints;
use Moo;

with 'Eval::WithLexicals::Role::Eval';
with 'Eval::WithLexicals::Role::LexicalHints';

1;
