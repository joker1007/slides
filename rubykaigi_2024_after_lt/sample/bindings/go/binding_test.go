package tree_sitter_sample_test

import (
	"testing"

	tree_sitter "github.com/smacker/go-tree-sitter"
	"github.com/tree-sitter/tree-sitter-sample"
)

func TestCanLoadGrammar(t *testing.T) {
	language := tree_sitter.NewLanguage(tree_sitter_sample.Language())
	if language == nil {
		t.Errorf("Error loading Sample grammar")
	}
}
