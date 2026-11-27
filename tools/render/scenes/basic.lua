-- A first look: the tracker after login, the main window, and the card game's window.
return function(T)
  T.step(1)
  T.shoot("login")
  T.slash("/wp")
  T.step(1)
  T.shoot("main")
  T.hideAll()
  T.slash("/wp arcade")
  T.step(2)
  T.shoot("arcade")
end
