export type AuthPage =
  | "login"
  | "signUp"
  | "forgotPassword"
  | "verification"
  | "resetPassword"
  | "dashboard";

export type Navigate = (page: AuthPage) => void;