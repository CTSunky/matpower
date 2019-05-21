function opt = gurobi_options(overrides, mpopt)
%GUROBI_OPTIONS  Sets options for GUROBI (version 5.x and greater).
%
%   OPT = GUROBI_OPTIONS
%   OPT = GUROBI_OPTIONS(OVERRIDES)
%   OPT = GUROBI_OPTIONS(OVERRIDES, FNAME)
%   OPT = GUROBI_OPTIONS(OVERRIDES, MPOPT)
%
%   Sets the values for the options struct normally passed to GUROBI.
%
%   Inputs are all optional, second argument must be either a string
%   (FNAME) or a struct (MPOPT):
%
%       OVERRIDES - struct containing values to override the defaults
%       FNAME - name of user-supplied function called after default
%           options are set to modify them. Calling syntax is:
%                   MODIFIED_OPT = FNAME(DEFAULT_OPT);
%       MPOPT - MATPOWER options struct, uses the following fields:
%           opf.violation    - used to set opt.FeasibilityTol
%           verbose          - used to set opt.DisplayInterval,
%                                 opt.OutputFlag, opt.LogToConsole
%           gurobi.method    - used to set opt.Method
%           gurobi.timelimit - used to set opt.TimeLimit (seconds)
%           gurobi.threads   - used to set opt.Threads
%           gurobi.opts      - struct containing values to use as OVERRIDES
%           gurobi.opt_fname - name of user-supplied function used as FNAME,
%               except with calling syntax:
%                   MODIFIED_OPT = FNAME(DEFAULT_OPT, MPOPT);
%           gurobi.opt       - numbered user option function, if and only if
%               gurobi.opt_fname is empty and gurobi.opt is non-zero, the value
%               of gurobi.opt_fname is generated by appending gurobi.opt to
%               'gurobi_user_options_' (for backward compatibility with old
%               MATPOWER option GRB_OPT).
%
%   Output is a parameter struct to pass to GUROBI.
%
%   There are multiple ways of providing values to override the default
%   options. Their precedence and order of application are as follows:
%
%   With inputs OVERRIDES and FNAME
%       1. FNAME is called
%       2. OVERRIDES are applied
%   With inputs OVERRIDES and MPOPT
%       1. FNAME (from gurobi.opt_fname or gurobi.opt) is called
%       2. gurobi.opts (if not empty) are applied
%       3. OVERRIDES are applied
%
%   Example:
%
%   If gurobi.opt = 3, then after setting the default GUROBI options,
%   GUROBI_OPTIONS will execute the following user-defined function
%   to allow option overrides:
%
%       opt = gurobi_user_options_3(opt, mpopt);
%
%   The contents of gurobi_user_options_3.m, could be something like:
%
%       function opt = gurobi_user_options_3(opt, mpopt)
%       opt.OptimalityTol   = 1e-9;
%       opt.BarConvTol      = 1e-9;
%       opt.IterationLimit  = 3000;
%       opt.BarIterLimit    = 200;
%       opt.Crossover       = 0;
%       opt.Presolve        = 0;
%
%   For details on the available options, see the "Parameters" section
%   of the "Gurobi Optimizer Reference Manual" at:
%
%       https://www.gurobi.com/documentation/
%
%   See also GUROBI, MPOPTION.

%   MATPOWER
%   Copyright (c) 2010-2016, Power Systems Engineering Research Center (PSERC)
%   by Ray Zimmerman, PSERC Cornell
%
%   This file is part of MATPOWER.
%   Covered by the 3-clause BSD License (see LICENSE file for details).
%   See http://www.pserc.cornell.edu/matpower/ for more info.

%%-----  initialization and arg handling  -----
%% defaults
verbose = 1;
fname   = '';

%% second argument
if nargin > 1 && ~isempty(mpopt)
    if ischar(mpopt)        %% 2nd arg is FNAME (string)
        fname = mpopt;
        have_mpopt = 0;
    else                    %% 2nd arg is MPOPT (MATPOWER options struct)
        have_mpopt = 1;
        verbose = mpopt.verbose;
        if isfield(mpopt.gurobi, 'opt_fname') && ~isempty(mpopt.gurobi.opt_fname)
            fname = mpopt.gurobi.opt_fname;
        elseif mpopt.gurobi.opt
            fname = sprintf('gurobi_user_options_%d', mpopt.gurobi.opt);
        end
    end
else
    have_mpopt = 0;
end

%%-----  set default options for Gurobi  -----
% opt.OptimalityTol = 1e-6;
% opt.Presolve = -1;              %% -1 - auto, 0 - no, 1 - conserv, 2 - aggressive=
% opt.LogFile = 'qps_gurobi.log';
if have_mpopt
    %% (make default opf.violation correspond to default FeasibilityTol)
    opt.FeasibilityTol  = mpopt.opf.violation/5;
    opt.Method          = mpopt.gurobi.method;
    opt.TimeLimit       = mpopt.gurobi.timelimit;
    opt.Threads         = mpopt.gurobi.threads;
else
    opt.Method          = -1;           %% automatic
end
if verbose > 1
    opt.LogToConsole = 1;
    opt.OutputFlag = 1;
    if verbose > 2
        opt.DisplayInterval = 1;
    else
        opt.DisplayInterval = 100;
    end
else
    opt.LogToConsole = 0;
    opt.OutputFlag = 0;
end

%%-----  call user function to modify defaults  -----
if ~isempty(fname)
    if have_mpopt
        opt = feval(fname, opt, mpopt);
    else
        opt = feval(fname, opt);
    end
end

%%-----  apply overrides  -----
if have_mpopt && isfield(mpopt.gurobi, 'opts') && ~isempty(mpopt.gurobi.opts)
    opt = nested_struct_copy(opt, mpopt.gurobi.opts);
end
if nargin > 0 && ~isempty(overrides)
    opt = nested_struct_copy(opt, overrides);
end
