import { getSignerKeypair } from "../helpers/getSigner";
import { MULTISIG } from "../config";

/**
 * Type definition for a multisig user configuration.
 */
interface MultisigUser {
  SK: string;
  PK: string;
  ADDRESS: string;
  WEIGHT: number;
}

/**
 * Prepares the multisig configuration based on the MULTISIG configuration in the environment variables.
 *
 * @returns An object containing the multisig users and the threshold.
 */
export function getMultisigConfig(): {
  users: { keypair: ReturnType<typeof getSignerKeypair>; weight: number }[];
  threshold: number;
} {
  // Extract the multisig users from the configuration
  const users = Object.entries(MULTISIG)
    .filter(([key]) => key.startsWith("USER_")) // Include only user-specific keys
    .map(([_, user]) => {
      const multisigUser = user as MultisigUser; // Cast to MultisigUser
      return {
        keypair: getSignerKeypair(multisigUser.SK), // Retrieve the keypair using the secret key
        weight: multisigUser.WEIGHT, // Use the defined weight
      };
    });

  return {
    users,
    threshold: MULTISIG.THRESHOLD, // Use the configured threshold
  };
}
