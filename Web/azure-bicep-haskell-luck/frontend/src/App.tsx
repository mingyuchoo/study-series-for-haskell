import { onMount, type Component } from "solid-js";
import { Router, Route } from "@solidjs/router";
import Layout from "./components/Layout";
import Login from "./pages/Login";
import Signup from "./pages/Signup";
import Dashboard from "./pages/Dashboard";
import Calendar from "./pages/Calendar";
import Profile from "./pages/Profile";
import Admin from "./pages/Admin";
import { auth } from "./lib/store";

const App: Component = () => {
  // 401 발생 시 전역 로그아웃 (Layout 효과가 /login 으로 보낸다)
  onMount(() => {
    window.addEventListener("luck:unauthorized", () => auth.logout());
  });

  return (
    <Router>
      <Route path="/login" component={Login} />
      <Route path="/signup" component={Signup} />
      <Route path="/" component={Layout}>
        <Route path="/" component={Dashboard} />
        <Route path="/day/:date" component={Dashboard} />
        <Route path="/calendar" component={Calendar} />
        <Route path="/profile" component={Profile} />
        <Route path="/admin" component={Admin} />
      </Route>
    </Router>
  );
};

export default App;
