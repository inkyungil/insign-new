export interface AuthResponse {
  user: {
    id: number;
    email: string;
    displayName?: string | null;
    lastLoginAt?: Date | null;
    provider?: string;
    avatarUrl?: string | null;
  };
  accessToken: string;
  expiresIn: number;
}
