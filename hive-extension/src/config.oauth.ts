// Default OAuth config for production builds
// Replace DEFAULT_GOOGLE_CLIENT_ID during release so users can click Sign in without setup.
export const DEFAULT_GOOGLE_CLIENT_ID = ""; // e.g. 1234567890-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
export const DEFAULT_GOOGLE_SCOPES = "https://www.googleapis.com/auth/generative-language";

export function getDefaultGoogleOAuth(){
  return { clientId: DEFAULT_GOOGLE_CLIENT_ID, scopes: DEFAULT_GOOGLE_SCOPES };
}
