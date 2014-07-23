require File.expand_path("spec_helper", File.dirname(__FILE__))

describe "capturing" do
  it "doesn't yield the verb" do
    app do |r|
      r.get do |*args|
        args.size.to_s
      end
    end

    body.should == '0'
  end

  it "doesn't yield the path" do
    app do |r|
      r.get "home" do |*args|
        args.size.to_s
      end
    end

    body('/home').should == '0'
  end

  it "yields the segment" do
    app do |r|
      r.get "user", :id do |id|
        id
      end
    end

    body("/user/johndoe").should == 'johndoe'
  end

  it "yields a number" do
    app do |r|
      r.get "user", :id do |id|
        id
      end
    end

    body("/user/101").should == '101'
  end

  it "yield a file name with a matching extension" do
    app do |r|
      r.get "css", :extension=>"css" do |file|
        file
      end
    end

    body("/css/app.css").should == 'app'
  end

  it "yields a segment per nested block" do
    app do |r|
      r.on :one do |one|
        r.on :two do |two|
          r.on :three do |three|
            response.write one
            response.write two
            response.write three
          end
        end
      end
    end

    body("/one/two/three").should == "onetwothree"
  end

  it "consumes a slash if needed" do
    app do |r|
      r.get "(.+\\.css)" do |file|
        file
      end
    end

    body("/foo/bar.css").should == "foo/bar.css"
  end

  it "regex captures in string format" do
    app do |r|
      r.get "posts/(\\d+)-(.*)" do |id, slug|
        response.write id
        response.write slug
      end
    end

    body("/posts/123-postal-service").should == "123postal-service"
  end

  it "regex captures in regex format" do
    app do |r|
      r.get %r{posts/(\d+)-(.*)} do |id, slug|
        response.write id
        response.write slug
      end
    end

    body("/posts/123-postal-service").should == "123postal-service"
  end
end

describe "r.is" do 
  it "ensures the patch is matched fully" do
    app do |r|
      r.is "" do
        "+1"
      end
    end

    body.should == '+1'
    status('//').should == 404
  end

  it "handles no arguments" do
    app do |r|
      r.on "" do
        r.is do
          "+1"
        end
      end
    end

    body.should == '+1'
    status('//').should == 404
  end

  it "matches strings" do
    app do |r|
      r.is "123" do
        "+1"
      end
    end

    body("/123").should == '+1'
    status("/123/").should == 404
  end

  it "matches regexps" do
    app do |r|
      r.is /(\w+)/ do |id|
        id
      end
    end

    body("/123").should == '123'
    status("/123/").should == 404
  end

  it "matches segments" do
    app do |r|
      r.is :id do |id|
        id
      end
    end

    body("/123").should == '123'
    status("/123/").should == 404
  end
end

describe "matchers" do
  it "should handle string with embedded param" do
    app do |r|
      r.on "posts/:id" do |id|
        id
      end
    end

    body('/posts/123').should == '123'
    status('/post/123').should == 404
  end

  it "should handle multiple params in single string" do
    app do |r|
      r.on "u/:uid/posts/:id" do |uid, id|
        uid + id
      end
    end

    body("/u/jdoe/posts/123").should == 'jdoe123'
    status("/u/jdoe/pots/123").should == 404
  end

  it "should handle regexes and nesting" do
    app do |r|
      r.on(/u\/(\w+)/) do |uid|
        r.on(/posts\/(\d+)/) do |id|
          uid + id
        end
      end
    end

    body("/u/jdoe/posts/123").should == 'jdoe123'
    status("/u/jdoe/pots/123").should == 404
  end

  it "should handle regex nesting colon param style" do
    app do |r|
      r.on(/u:(\w+)/) do |uid|
        r.on(/posts:(\d+)/) do |id|
          uid + id
        end
      end
    end

    body("/u:jdoe/posts:123").should == 'jdoe123'
    status("/u:jdoe/poss:123").should == 404
  end

  it "symbol matching" do
    app do |r|
      r.on "user", :id do |uid|
        r.on "posts", :pid do |id|
          uid + id
        end
      end
    end

    body("/user/jdoe/posts/123").should == 'jdoe123'
    status("/user/jdoe/pots/123").should == 404
  end

  it "paths and numbers" do
    app do |r|
      r.on "about" do
        r.on :one, :two do |one, two|
          one + two
        end
      end
    end

    body("/about/1/2").should == '12'
    status("/about/1").should == 404
  end

  it "paths and decimals" do
    app do |r|
     r.on "about" do
        r.on(/(\d+)/) do |one|
          one
        end
      end
    end

    body("/about/1").should == '1'
    status("/about/1.2").should == 404
  end

  it "should allow arrays to match any value" do
    app do |r|
      r.on [/(\d+)/, /\d+(bar)?/] do |id|
        id
      end
    end

    body('/123').should == '123'
    body('/123bar').should == 'bar'
    status('/123bard').should == 404
  end

  it "should have array capture match string if match" do
    app do |r|
      r.on %w'p q' do |id|
        id
      end
    end

    body('/p').should == 'p'
    body('/q').should == 'q'
    status('/r').should == 404
  end
end

describe "r.on" do 
  it "executes on no arguments" do
    app do |r|
      r.on do
        "+1"
      end
    end

    body.should == '+1'
  end

  it "executes on true" do
    app do |r|
      r.on true do
        "+1"
      end
    end

    body.should == '+1'
  end

  it "executes on non-false" do
    app do |r|
      r.on "123" do
        "+1"
      end
    end

    body("/123").should == '+1'
  end

  it "ensures SCRIPT_NAME and PATH_INFO are reverted" do
    app do |r|
      r.on lambda { r.env["SCRIPT_NAME"] = "/hello"; false } do
        "Unreachable"
      end
      
      r.on do
        r.env["SCRIPT_NAME"] + ':' + r.env["PATH_INFO"]
      end
    end

    body("/hello").should == ':/hello'
  end

  it "doesn't mutate SCRIPT_NAME or PATH_INFO after request is returned" do
    app do |r|
      r.on 'login', 'foo' do 
        "Unreachable"
      end
      
      r.on do
        r.env["SCRIPT_NAME"] + ':' + r.env["PATH_INFO"]
      end
    end

    pi, sn = '/login', ''
    env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => pi, "SCRIPT_NAME" => sn}
    app.call(env)[2].join.should == ":/login"
    env["PATH_INFO"].should equal(pi)
    env["SCRIPT_NAME"].should equal(sn)
  end

  it "skips consecutive matches" do
    app do |r|
      r.on do
        "foo"
      end

      r.on do
        "bar"
      end
    end

    body.should == "foo"
  end

  it "finds first match available" do
    app do |r|
      r.on false do
        "foo"
      end

      r.on do
        "bar"
      end
    end

    body.should == "bar"
  end

  it "reverts a half-met matcher" do
    app do |r|
      r.on "post", false do
        "Should be unmet"
      end

      r.on do
        r.env["SCRIPT_NAME"] + ':' + r.env["PATH_INFO"]
      end
    end

    body("/hello").should == ':/hello'
  end
end

describe "param matcher" do
  it "should yield a param only if given" do
    app do |r|
      r.get "signup", :param=>"email" do |email|
        email
      end

      r.on do
        "No email"
      end
    end

    io = StringIO.new
    body("/signup", "rack.input" => io, "QUERY_STRING" => "email=john@doe.com").should == 'john@doe.com'
    body("/signup", "rack.input" => io, "QUERY_STRING" => "").should == 'No email'
    body("/signup", "rack.input" => io, "QUERY_STRING" => "email=").should == ''
  end
end

describe "path matchers" do 
  it "one level path" do
    app do |r|
      r.on "about" do
        "About"
      end
    end

    body('/about').should == "About"
    status("/abot").should == 404
  end

  it "two level nested paths" do
    app do |r|
      r.on "about" do
        r.on "1" do
          "+1"
        end

        r.on "2" do
          "+2"
        end
      end
    end

    body('/about/1').should == "+1"
    body('/about/2').should == "+2"
    status('/about/3').should == 404
  end

  it "two level inlined paths" do
    app do |r|
      r.on "a/b" do
        "ab"
      end
    end

    body('/a/b').should == "ab"
    status('/a/d').should == 404
  end

  it "a path with some regex captures" do
    app do |r|
      r.on "user(\\d+)" do |uid|
        uid
      end
    end

    body('/user123').should == "123"
    status('/useradf').should == 404
  end

  it "matching the root" do
    app do |r|
      r.on "" do
        "Home"
      end
    end

    body.should == 'Home'
    status("/foo").should == 404
  end
end

describe "root/empty segment matching" do
  it "matching an empty segment" do
    app do |r|
      r.on "" do
        r.path
      end
    end

    body.should == '/'
    status("/foo").should == 404
  end

  it "nested empty segments" do
    app do |r|
      r.on "" do
        r.on "" do
          r.on "1" do
            r.path
          end
        end
      end
    end

    body("///1").should == '///1'
    status("/1").should == 404
    status("//1").should == 404
  end

  it "/events/? scenario" do
    a = app do |r|
      r.on "" do
        "Hooray"
      end

      r.is do
        "Foo"
      end
    end

    app(:new) do |r|
      r.on "events" do
        r.run a
      end
    end

    body("/events").should == 'Foo'
    body("/events/").should == 'Hooray'
    status("/events/foo").should == 404
  end
end

describe "segment handling" do
  before do
    app do |r|
      r.on "post" do
        r.on :id do |id|
          id
        end
      end
    end
  end

  it "matches numeric ids" do
    body('/post/1').should == '1'
  end

  it "matches decimal numbers" do
    body('/post/1.1').should == '1.1'
  end

  it "matches slugs" do
    body('/post/my-blog-post-about-cuba').should == 'my-blog-post-about-cuba'
  end

  it "matches only the first segment available" do
    body('/post/one/two/three').should == 'one'
  end
end

describe "request verb methods" do 
  it "executes on true" do
    app do |r|
      r.get do
        "g"
      end
      r.post do
        "p"
      end
    end

    body.should == 'g'
    body('REQUEST_METHOD'=>'POST').should == 'p'
  end
end

describe "extension matcher" do
  it "should match given file extensions" do
    app do |r|
      r.on "styles" do
        r.on :extension=>"css" do |file|
          file
        end
      end
    end

    body("/styles/reset.css").should == 'reset'
    status("/styles/reset.bar").should == 404
  end
end
