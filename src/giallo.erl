%% ----------------------------------------------------------------------------
%%
%% giallo: A small and flexible web framework
%%
%% Copyright (c) 2013 KIVRA
%%
%% Permission is hereby granted, free of charge, to any person obtaining a
%% copy of this software and associated documentation files (the "Software"),
%% to deal in the Software without restriction, including without limitation
%% the rights to use, copy, modify, merge, publish, distribute, sublicense,
%% and/or sell copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
%% DEALINGS IN THE SOFTWARE.
%%
%% ----------------------------------------------------------------------------

%% @doc API for stoping and starting Giallo and convenience function.
%%
%% Giallo uses standard Cowboy features and makes it easy to mix and match
%% conventient Giallo modules with the full power of Cowboy, REST-handlers,
%% etc.
%%
%% This module provides functions for starting and stopping Giallo as well as
%% some convenience functions for working with headers, parameters and
%% multipart data.
%% @end

-module(giallo).

-include("giallo.hrl").

-export([start/1]).
-export([start/2]).
-export([stop/0]).

-export([header/2]).
-export([header/3]).
-export([post_param/2]).
-export([post_param/3]).
-export([post_param/4]).
-export([query_param/2]).
-export([query_param/3]).
-export([multipart_file/2]).
-export([multipart_param/2]).
-export([multipart_param/3]).
-export([multipart_stream/4]).

-opaque giallo_req() :: #g{}.
-export_type([giallo_req/0]).

%% API ------------------------------------------------------------------------

%% @equiv start(Dispatch, [])
-spec start(Dispatch) -> {ok, pid()} | {error, Reason} when
    Dispatch :: cowboy_router:routes(),
    Reason   :: term().
start(Dispatch) ->
    start(Dispatch, []).

%% @doc
%% Start Giallo with the given routes and an options proplist with
%% arguments for Giallo. Optional arguments would be one of:
%% <dl>
%% <dt>acceptors:</dt>
%%   <dd>Number of acceptors that Cowboy should start,
%%       Default:<em>[{acceptors, 100}]</em></dd>
%% <dt>port:</dt>
%%   <dd>The port on which Giallo should listen to,
%%       Default: <em>[{port, 8080}]</em></dd>
%% </dl>
-spec start(Dispatch, Env) -> {ok, pid()} | {error, Reason} when
    Dispatch :: cowboy_router:routes(),
    Env      :: proplists:proplist(),
    Reason   :: term().
start(Dispatch, Env) ->
    CompiledDispatch = cowboy_router:compile(Dispatch),
    {ok, Acceptors}  = get_env(acceptors, Env),
    {ok, Port}       = get_env(port, Env),
    cowboy:start_http(giallo_http_listener, Acceptors, [{port, Port}], [
            {env, [{dispatch, CompiledDispatch}]},
            {middlewares, [cowboy_router, giallo_middleware,
                           cowboy_handler]}
            ]).

%% @doc Stop Giallo
-spec stop() -> ok | {error, Reason} when
    Reason :: term().
stop() ->
    application:stop(giallo).

%% Req Convenience functions --------------------------------------------------

%% @equiv post_param(Key, Req0, undefined)
-spec post_param(Key, Req0) -> Result when
    Key     :: binary(),
    Req0    :: cowboy_req:req(),
    Result  :: {binary() | undefined, cowboy_req:req()} | {error, atom()}.
post_param(Key, Req0) ->
    post_param(Key, Req0, undefined).

%% @equiv post_param(Key, Req0, Default, 16000)
-spec post_param(Key, Req0, Default) -> Result when
    Key     :: binary(),
    Req0    :: cowboy_req:req(),
    Default :: any(),
    Result  :: {binary() | undefined, cowboy_req:req()} | {error, atom()}.
post_param(Key, Req0, Default) ->
    post_param(Key, Req0, Default, 16000).

%% @doc
%% Return a named parameter from a HTTP POST or <em>Default</em> if not found,
%% see <em>query_param/2</em> for query parameter retrieving.
%%
%% There's a default limit on body post size on 16kb, if that limit is
%% exceeded a <em>{error, badlength}</em> will get returned. You can
%% optionally pass in an other value for <em>MaxBodyLength</em> or the atom
%% <em>infinity</em> to bypass size constraints
-spec post_param(Key, Req0, Default, MaxBodyLength) -> Result  when
    Key           :: binary(),
    Req0          :: cowboy_req:req(),
    Default       :: any(),
    MaxBodyLength :: non_neg_integer() | infinity,
    Result        :: {binary() | Default, cowboy_req:req()} | {error, atom()}.
post_param(Key, Req0, Default, MaxBodyLength) ->
    case cowboy_req:body(MaxBodyLength, Req0) of
        {error, _} = E     -> E;
        {ok, Buffer, Req1} ->
            BodyQs = cowboy_http:x_www_form_urlencoded(Buffer),
            Req2   = cowboy_req:set([{buffer, Buffer}], Req1),
            Req3   = cowboy_req:set([{body_state, waiting}], Req2),
            case lists:keyfind(Key, 1, BodyQs) of
                {Key, Value} -> {Value, Req3};
                false        -> {Default, Req3}
            end
    end.

%% @equiv query_param(Key, Req0, undefined)
-spec query_param(Key, Req0) -> Result when
    Key     :: binary(),
    Req0    :: cowboy_req:req(),
    Result  :: {binary() | undefined, cowboy_req:req()}.
query_param(Key, Req0) ->
    query_param(Key, Req0, undefined).

%% @doc
%% Return a named parameter from the querystring or <em>Default</em>
%% if not found, see <em>post_param/2</em> for HTTP POST parameter retrieving.
-spec query_param(Key, Req0, Default) -> Result when
    Key     :: binary(),
    Req0    :: cowboy_req:req(),
    Default :: any(),
    Result  :: {binary() | Default, cowboy_req:req()}.
query_param(Key, Req0, Default) ->
    cowboy_req:qs_val(Key, Req0, Default).

%% @equiv header(Key, Req0, undefined)
-spec header(Key, Req0) -> {binary() | undefined, cowboy_req:req()} when
    Key     :: binary(),
    Req0    :: cowboy_req:req().
header(Key, Req0) ->
    header(Key, Req0, undefined).

%% @doc
%% Return a named HTTP Header from the Request or <em>Default</em>
%% if not found.
-spec header(Key, Req0, Default) -> Result when
    Key     :: binary(),
    Req0    :: cowboy_req:req(),
    Default :: any(),
    Result  :: {binary() | Default, cowboy_req:req()}.
header(Key, Req0, Default) ->
    cowboy_req:header(Key, Req0, Default).

%% @equiv multipart_param(Key, Req0, undefined)
-spec multipart_param(Key, Req0) -> binary() | undefined when
    Key     :: binary(),
    Req0    :: cowboy_req:req().
multipart_param(Key, Req0) ->
    multipart_param(Key, Req0, undefined).

%% @doc
%% Returns the value of a multipart request, or Default if not found.
-spec multipart_param(Key, Req0, Default) -> binary() | Default when
    Key     :: binary(),
    Req0    :: cowboy_req:req(),
    Default :: any().
multipart_param(Key, Req0, Default) ->
    case giallo_multipart:param(Key, Req0) of
        undefined -> Default;
        Value     -> Value
    end.

%% @doc
%% Locates a multipart field named Param, assumed to contain a file.
%% Returns {Filename, Body}, where Filename is the result of decoding
%% the "filename" part of the Content-Disposition header.
-spec multipart_file(Key, Req0) -> {binary(), binary()} | undefined when
    Key     :: binary(),
    Req0    :: cowboy_req:req().
multipart_file(Key, Req0) ->
    giallo_multipart:file(Key, Req0).

%% @doc
%% Streams fragments of a multipart part by repeatedly calling
%% <em>Fun(Fragment, Meta, State)</em> where Fragment is a binary containing
%% a part of the body, Meta contains the header fields of the part,
%% and State is a user-specified updated on each call to Fun.
%% When the end of the part is reached, Fun is called with Fragment
%% set to the atom "eof".
-spec multipart_stream(Key, Fun, State, Req0) ->
                                {binary(), binary()} | undefined when
    Key     :: binary(),
    Fun     :: fun(),
    State   :: any(),
    Req0    :: cowboy_req:req().
multipart_stream(Key, Fun, State, Req0) ->
    giallo_multipart:stream_param(Key, Fun, State, Req0).

%% Private --------------------------------------------------------------------

get_env(Key, Env) ->
    case lists:keyfind(Key, 1, Env) of
        {Key, Val} -> {ok, Val};
        false      -> application:get_env(giallo, Key)
    end.
