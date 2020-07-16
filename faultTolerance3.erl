%%%-------------------------------------------------------------------
%%% @author Lasascht
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 16. 7月 2020 19:11
%%%-------------------------------------------------------------------
-module(faultTolerance3).
-author("Lasascht").

%% API
-export([start/1,server/2,allocate/0,free/1,start_client/0,loop/0]).
start(Resources) ->
  Pid = spawn(allocator, server, [Resources,[]]),
  register(resource_alloc, Pid).
% Function
allocate() ->
  request(alloc).
free(Resource) ->
  request({free,Resource}).
request(Request) ->
  resource_alloc ! {self(),Request},
  receive
    {resource_alloc, error} ->
      exit(bad_allocation); % exit added here
    {resource_alloc, Reply} ->
      Reply
  end.
% The server.
server(Free, Allocated) ->
  process_flag(trap_exit, true),
  receive
    {From,alloc} ->
      allocate(Free, Allocated, From);
    {From,{free,R}} ->
      free(Free, Allocated, From, R);
    {'EXIT', From, _ } ->
      check(Free, Allocated, From)
  end.
allocate([R|Free], Allocated, From) ->
  link(From),
  io:format("Connnect to server~w~n",[From]),
  From ! {resource_alloc,{yes,R}},
  server(Free, [{R,From}|Allocated]);
allocate([], Allocated, From) ->
  From ! {resource_alloc,no},
  server([], Allocated).
free(Free, Allocated, From, R) ->
  case lists:member({R,From}, Allocated) of
    true ->
      From ! {resource_alloc,ok},
      Allocated1 = lists:delete({R, From}, Allocated),
      case lists:keysearch(From,2,Allocated1) of
        false->
          unlink(From),
          io:format("Stop from~w~n",[From]);
        _->
          true
      end,
      server([R|Free],Allocated1);
    false ->
      From ! {resource_alloc,error},
      server(Free, Allocated)
  end.

check(Free, Allocated, From) ->
  case lists:keysearch(From, 2, Allocated) of
    false ->
      server(Free, Allocated);
    {value, {R, From}} ->
      check([R|Free],
        lists:delete({R, From}, Allocated), From)
  end.
start_client()->
  Pid2=spawn(allocator,loop,[]),
  register(client, Pid2).
loop()->
  receive
    allocate->
      allocate(),
      loop();
    {free,Resource}->
      free(Resource),
      loop();
    stop->
      true;
    _->
      loop()
  end.
