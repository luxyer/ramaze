require 'spec'
require File.expand_path(__FILE__).gsub('/spec/', '/lib/ramaze/')

describe 'String#/ and Symbol#/' do
  it 'should join two strings' do
    ('a' / 'b').should == 'a/b'
  end

  it 'should join a string and a symbol' do
    ('a' / :b).should == 'a/b'
  end

  it 'should join two symbols' do
    (:a / :b).should == 'a/b'
  end

  it 'should be usable in concatenation' do
    ('a' / :b / :c).should == 'a/b/c'
  end
end
