import React, { useState } from "react";
import { KeyRound } from "lucide-react";
import AuthLayout from "../components/auth/AuthLayout";
import AuthCard from "../components/auth/AuthCard";
import {
  AuthIcon,
  AuthTitle,
  AuthDescription,
  AuthButton,
  AuthLink,
  FormMessage,
  AuthField,
} from "../components/auth/AuthElements";
import { resetPassword } from "../services/authService";

interface ResetPasswordPageProps {
  phoneNumber: string;
  verificationCode: string;
  onNavigateToLogin: () => void;
}

const ResetPasswordPage: React.FC<ResetPasswordPageProps> = ({
  phoneNumber,
  verificationCode,
  onNavigateToLogin,
}) => {
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleReset = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);

    if (!newPassword || !confirmPassword) {
      setErrorMessage("Please fill in all fields");
      return;
    }
    if (newPassword !== confirmPassword) {
      setErrorMessage("Passwords do not match");
      return;
    }
    if (newPassword.length < 8) {
      setErrorMessage("Password must be at least 8 characters long");
      return;
    }

    setIsLoading(true);
    const result = await resetPassword({ phoneNumber, verificationCode, newPassword });
    setIsLoading(false);

    if (result.success) {
      onNavigateToLogin();
    } else {
      setErrorMessage(result.message ?? "Something went wrong");
    }
  };

  return (
    <AuthLayout>
      <AuthCard>
        <AuthIcon icon={KeyRound} size={34} />
        <AuthTitle>Reset Password</AuthTitle>
        <AuthDescription>Create a new, strong password to secure your account.</AuthDescription>
        <p className="password-requirements">Must be at least 8 characters</p>

        <form onSubmit={handleReset} noValidate>
          <AuthField
            label="New Password"
            type="password"
            placeholder="Enter new password"
            value={newPassword}
            onChange={setNewPassword}
          />
          <AuthField
            label="Confirm New Password"
            type="password"
            placeholder="Confirm new password"
            value={confirmPassword}
            onChange={setConfirmPassword}
          />

          {errorMessage && <FormMessage text={errorMessage} type="error" />}

          <AuthButton label={isLoading ? "Resetting..." : "Reset Password"} isLoading={isLoading} />
        </form>

        <AuthLink onClick={onNavigateToLogin} muted>
          Cancel
        </AuthLink>
      </AuthCard>
    </AuthLayout>
  );
};

export default ResetPasswordPage;