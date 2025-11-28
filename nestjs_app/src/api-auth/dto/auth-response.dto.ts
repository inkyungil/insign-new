export interface AuthResponse {
  user: {
    id: number;
    email: string;
    displayName?: string | null;
    lastLoginAt?: Date | null;
    provider?: string;
    avatarUrl?: string | null;
    agreedToTerms?: boolean;
    agreedToPrivacy?: boolean;
    agreedToSensitive?: boolean;
    agreedToMarketing?: boolean;
  };
  accessToken: string;
  expiresIn: number;
  requiresTermsAgreement?: boolean;
}
