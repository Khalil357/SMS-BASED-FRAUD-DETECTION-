import React, { useRef } from "react";
import "./OtpFields.css";

interface OtpFieldsProps {
  values: string[];
  onChange: (values: string[]) => void;
}

const OtpFields: React.FC<OtpFieldsProps> = ({ values, onChange }) => {
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

  const handleChange = (index: number, digit: string) => {
    const clean = digit.replace(/[^0-9]/g, "").slice(-1);
    const next = [...values];
    next[index] = clean;
    onChange(next);

    if (clean && index < values.length - 1) {
      inputRefs.current[index + 1]?.focus();
    }
  };

  const handleKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Backspace" && !values[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
  };

  return (
    <div className="otp-fields">
      {values.map((digit, index) => (
        <input
          key={index}
          ref={(el) => {
            inputRefs.current[index] = el;
          }}
          type="text"
          inputMode="numeric"
          maxLength={1}
          value={digit}
          onChange={(e) => handleChange(index, e.target.value)}
          onKeyDown={(e) => handleKeyDown(index, e)}
          className="otp-box"
        />
      ))}
    </div>
  );
};

export default OtpFields;