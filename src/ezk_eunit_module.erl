-module(ezk_eunit_module).
-include_lib("eunit/include/eunit.hrl").

-define(TO_RUN_SINGLE,600).  %% 200   rounds              -> 9 ,6s
                             %% 2000  rounds              -> 95  s  

-define(TO_RUN_MULTI,10000). %% 20   clients, 50   rounds -> 11,6s
                             %% 100  clients, 25   rounds -> 10  s
                             %% 200  clients, 50   rounds -> 30  s 
                             %% 1000 clients, 25   rounds -> 61  s 

-define(TO_LS_SINGLE,10).    %% 900  lses                 -> 0,4s

-define(TO_LS_MULTI,300).    %% 2000 clients, 900 lses    -> 173s

-define(RUN_CYCLES       , 50).
-define(RUN_CLIENTS      , 500).
-define(RUN_SINGLE_ROUNDS, 200).

-define(LS_CLIENTS, 20).
-define(LS_LSES, 90).

-export([random_str/1]).

test_test_() ->
    {setup, %%receive afters are there to wait till zkServer stops dropping messages.
     fun() -> application:start(ezk), receive after 3000 -> ok end  end,
     fun(_) -> receive after 3000 -> application:stop(ezk) end end,      
     [ls_performance(), run()]}.


%% -----------------------------------------
%% Run
%% -----------------------------------------
 
run() ->
   [{"Single Run 1 (/100)", {timeout, ?TO_RUN_SINGLE, ?_assertEqual(ok,run_single(?RUN_SINGLE_ROUNDS div 100))}},
    {"Single Run 2 (/50)",  {timeout, ?TO_RUN_SINGLE, ?_assertEqual(ok,run_single(?RUN_SINGLE_ROUNDS div 50 ))}},
    {"Single Run 3 (/10)",  {timeout, ?TO_RUN_SINGLE, ?_assertEqual(ok,run_single(?RUN_SINGLE_ROUNDS div 10 ))}},
    {"Single Run 4 (/2)",   {timeout, ?TO_RUN_SINGLE, ?_assertEqual(ok,run_single(?RUN_SINGLE_ROUNDS div 2  ))}},
    {"Single Run 5 (/1)",   {timeout, ?TO_RUN_SINGLE, ?_assertEqual(ok,run_single(?RUN_SINGLE_ROUNDS div 1  ))}},
    {"Multi Run 1 (/100, /100)", {timeout, ?TO_RUN_MULTI, ?_assertEqual(ok,run_multi((?RUN_CLIENTS div 100),(?RUN_CYCLES div 100)))}},
    {"Multi Run 2 (/50, /50)",   {timeout, ?TO_RUN_MULTI, ?_assertEqual(ok,run_multi((?RUN_CLIENTS div 50 ),(?RUN_CYCLES div 50 )))}},
    {"Multi Run 3 (/50, /10)",   {timeout, ?TO_RUN_MULTI, ?_assertEqual(ok,run_multi((?RUN_CLIENTS div 50 ),(?RUN_CYCLES div 10 )))}},
    {"Multi Run 4 (/10, /50)",   {timeout, ?TO_RUN_MULTI, ?_assertEqual(ok,run_multi((?RUN_CLIENTS div 10 ),(?RUN_CYCLES div 50 )))}},
    {"Multi Run 5 (/10, /10)",   {timeout, ?TO_RUN_MULTI, ?_assertEqual(ok,run_multi((?RUN_CLIENTS div 10 ),(?RUN_CYCLES div 10 )))}},
    {"Multi Run 6 (/2, /2)",     {timeout, ?TO_RUN_MULTI, ?_assertEqual(ok,run_multi((?RUN_CLIENTS div 2  ),(?RUN_CYCLES div 2  )))}},
    {"Multi Run 7 (/1, /1)",     {timeout, ?TO_RUN_MULTI, ?_assertEqual(ok,run_multi((?RUN_CLIENTS div 1  ),(?RUN_CYCLES div 1  )))}}].

%% -----------------------------------------
%% Multi Run
%% -----------------------------------------

run_multi(Clients, Cycles) ->
    Self = self(),
    spawn(fun() -> run_multi_startall(Clients, Self, Cycles) end),
    receive
      papi ->
	   ok
    end.


run_multi_startall(0, Father, _Cycles) ->
    Father ! papi,
    ok;
run_multi_startall(I, Father, Cycles) ->
    Self = self(),
    spawn(fun() -> run_multi_startall(I-1, Self, Cycles) end),
    List = run_s_sequenzed_create("/run_multi",Cycles,[]),
    ?assertEqual(ok, run_s_test_data( List)),
    List2 = run_s_change_data(List,[]),
    ?assertEqual(ok, run_s_test_data( List2)),
    ?assertEqual(ok, run_s_delete_list(List2)),    
    receive
	papi -> Father ! papi
    end,
    ok.

%% -----------------------------------------
%% Single Run
%% -----------------------------------------

run_single(Rounds) ->
    Ls = ezk_connection:ls("/"),
    List = run_s_sequenzed_create("/run_single", Rounds,[]),
    ?assertEqual(ok, run_s_test_data(List)),
    List2 = run_s_change_data(List,[]),
    ?assertEqual(ok, run_s_test_data( List2)),
    ?assertEqual(ok, run_s_delete_list(List2)),
    ?assertEqual(Ls, ezk_connection:ls("/")),
    ok.

run_s_change_data([], List2) ->    
    List2;
run_s_change_data([{Path, _Data} | T], List2) ->
    Data2 = random_str(1000),
    {C, _I}  = ezk_connection:set(Path, Data2),
    ?assertEqual( ok, C), 
    run_s_change_data(T, [{Path, Data2} | List2 ]).

run_s_delete_list([]) ->
    ok;
run_s_delete_list([{Path, _Data} | T]) ->
    ?assertEqual({ok, Path}, ezk_connection:delete(Path)),
    run_s_delete_list(T).

run_s_test_data([]) ->
    ok;
run_s_test_data([{Path, Data} | T]) ->
    {ok, {Got, _I}} = ezk_connection:get(Path),
    ?assertEqual(Data, Got),
    run_s_test_data(T).

    
run_s_sequenzed_create(_Path, 0, List) -> 
    List;
run_s_sequenzed_create(Path, I, List) ->
    Data = random_str(1000),
    {ok,NewNode} = ezk_connection:create(Path, Data, s),
    run_s_sequenzed_create(Path, I-1, [{NewNode, Data} | List]).


    %% -----------------------------------------
    %% LS
    %% -----------------------------------------
ls_performance() ->
    [{"LS: One Single Client 1: (/100)", {timeout, ?TO_LS_SINGLE, ?_assertEqual(ok, ls_single(?LS_LSES div 100))}}, 
     {"LS: One Single Client 1: (/50)", {timeout, ?TO_LS_SINGLE, ?_assertEqual(ok, ls_single(?LS_LSES div 50))}}, 
     {"LS: One Single Client 1: (/10)", {timeout, ?TO_LS_SINGLE, ?_assertEqual(ok, ls_single(?LS_LSES div 10))}}, 
     {"LS: One Single Client 1: (/2)", {timeout, ?TO_LS_SINGLE, ?_assertEqual(ok, ls_single(?LS_LSES div 2))}}, 
     {"LS: One Single Client 1: (/1)", {timeout, ?TO_LS_SINGLE, ?_assertEqual(ok, ls_single(?LS_LSES))}}, 
     {"LS: Multiple Clients 1: (/100, /100)", {timeout, ?TO_LS_MULTI, ?_assertEqual(ok, ls_multi((?LS_CLIENTS div 100),(?LS_LSES div 100)))}},
     {"LS: Multiple Clients 1: (/50, /50)", {timeout, ?TO_LS_MULTI, ?_assertEqual(ok, ls_multi((?LS_CLIENTS div 50),(?LS_LSES div 50)))}},
     {"LS: Multiple Clients 1: (/10, /50)", {timeout, ?TO_LS_MULTI, ?_assertEqual(ok, ls_multi((?LS_CLIENTS div 10),(?LS_LSES div 50)))}},
     {"LS: Multiple Clients 1: (/50, /10)", {timeout, ?TO_LS_MULTI, ?_assertEqual(ok, ls_multi((?LS_CLIENTS div 50),(?LS_LSES div 10)))}},
     {"LS: Multiple Clients 1: (/10, /10)", {timeout, ?TO_LS_MULTI, ?_assertEqual(ok, ls_multi((?LS_CLIENTS div 10),(?LS_LSES div 10)))}},
     {"LS: Multiple Clients 1: (/2, /2)", {timeout, ?TO_LS_MULTI, ?_assertEqual(ok, ls_multi((?LS_CLIENTS div 2),(?LS_LSES div 2)))}},
     {"LS: Multiple Clients 1: (/1, /1)", {timeout, ?TO_LS_MULTI, ?_assertEqual(ok, ls_multi((?LS_CLIENTS div 1),(?LS_LSES div 1)))}}].

ls_single(Lses)->
    ls_lses(Lses),
    ok.

ls_multi(Clients,Lses)->
    Self = self(),
    spawn(fun() -> ls_startall(Clients, Self, Lses) end),
    receive
      papi ->
	   ok
    end.

ls_startall(0, Father, _Lses) ->
    Father ! papi,
    ok;
ls_startall(I, Father, Lses) ->
    Self = self(),
    spawn(fun() -> ls_startall(I-1, Self, Lses) end),
    ls_lses(Lses),
    receive
	papi -> Father ! papi
    end,
    ok.

ls_lses(0) ->
    ok;
ls_lses(I) ->
    ?assertEqual({ok,[<<"zookeeper">>]}, ezk_connection:ls("/")),
    ls_lses(I-1).

%%---------------------------------
%% Random
%%---------------------------------

    
random_str(0) -> [];
random_str(Len) -> [random_char()|random_str(Len-1)].
random_char() -> element(random:uniform(tuple_size(normalChars())), normalChars()).

%very ugly. don't try that at home kids.
normalChars() ->
    list_to_tuple(lists:seq(65,90) ++ lists:seq(97,122)).
