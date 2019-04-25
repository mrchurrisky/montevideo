hush -- don't worry if this is not defined
off  -- don't worry if this is not defined

-- Hopefully you'll never need to use these explicitly.
disp <- newDispatch'
tid <- startDispatchLoop' disp
off = killThread tid >> freeAll -- kill the program

-- These, though, you'll use a lot.
ch = replace' disp              -- change one thing
chAll = replaceAll' disp        -- change everything
stop = stopDispatch' disp       -- stop (and lose) one thing
hush = replaceAll' disp M.empty -- stop (and lose) everything
period = chTempoPeriod' disp
