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

-module(default_handler).

%-export([hi/3]).

%% Standard Cowboy callback handlers
-export([init/3]).
-export([handle/2]).
-export([terminate/3]).

%% Giallo callback handlers
-export([hi/4]).
-export([moved/4]).
-export([redirect/4]).
-export([render_other/4]).
-export([render_other_landing/4]).
-export([not_found/4]).
-export([error_500/4]).
-export([hello_world_template/4]).
-export([hello_world_template_var/4]).

%% Standard Cowboy callback handlers
init(_Transport, Req, []) ->
	{ok, Req, undefined}.

handle(Req, State) ->
	{ok, Req2} = cowboy_req:reply(200, [], <<"Hello World!">>, Req),
	{ok, Req2, State}.

terminate(_Reason, _Req, _State) ->
	ok.

%% Giallo callback handlers
hi(<<"GET">>, [<<"you">>], _Extra, _Req) ->
	{output, <<"Ohai!">>};
hi(<<"GET">>, [<<"json">>], _Extra, _Req) ->
    {json, [{<<"jason">>, <<"Ohai!">>}]};
hi(<<"GET">>, [<<"jsonp">>], _Extra, _Req) ->
    {jsonp, <<"callback">>, [{<<"jason">>, <<"Ohai!">>}]}.

moved(<<"GET">>, _Pathinfo, _Extra, _Req) ->
    {moved, <<"http://127.0.0.1:8080/hi/you">>}.

redirect(<<"GET">>, _Pathinfo, _Extra, _Req) ->
    {redirect, <<"http://127.0.0.1:8080/hi/you">>}.

render_other(<<"GET">>, _Pathinfo, _Extra, _Req) ->
    {render_other, [{action, render_other_landing},
                    {controller, default_handler}]}.

render_other_landing(<<"GET">>, [], _Extra, _Req) ->
	{output, <<"You got rendered!">>}.

not_found(<<"GET">>, _Pathinfo, _Extra, _Req) ->
    not_found.

error_500(<<"GET">>, _Pathinfo, _Extra, _Req) ->
    root_cause:analysis().

hello_world_template(<<"GET">>, _Pathinfo, _Extra, _Req) ->
    ok.

hello_world_template_var(<<"GET">>, _Pathinfo, _Extra, _Req) ->
    {ok, [{payload, <<"Hello World!">>}]}.