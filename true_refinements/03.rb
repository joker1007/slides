require_relative './unparser_base'
require_relative './ext'

refining(Ext) do
  "joker1007".hello
end

module Dummy; end

refining(Dummy) do
  "tagomoris".hello
end
