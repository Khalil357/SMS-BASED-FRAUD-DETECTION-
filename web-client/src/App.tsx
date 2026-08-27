import LoginPage from "./pages/LoginPage";
import { ThemeProvider } from "./theme/ThemeContext";

type AuthPage = "login" | "signUp" | "forgotPassword" | "dashboard";

function App() {
  const handleNavigate = (page: AuthPage) => {
    // Swap this for real routing once forgotPassword/dashboard/signUp pages exist
    console.log("navigate to", page);
  };

  return (
    <ThemeProvider>
      <LoginPage onNavigate={handleNavigate} />
    </ThemeProvider>
  );
}

export default App;