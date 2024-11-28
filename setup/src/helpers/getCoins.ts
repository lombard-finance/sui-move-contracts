import { SuiClient, PaginatedCoins, CoinStruct } from "@mysten/sui/client";

/// Recursively retrieves all MEMEFI coins of a given type owned by an address
async function getAllCoins(
  client: SuiClient,
  address: string,
  coinType: string,
  nextCursor: string | null = null
): Promise<CoinStruct[]> {
  // Fetch paginated MEMEFI coins
  const paginatedCoins: PaginatedCoins = await client.getCoins({
    owner: address,
    coinType: coinType,
    cursor: nextCursor, // start from the next cursor
  });

  // Add the current page of coins to the allCoins array
  const currentCoins = paginatedCoins.data;

  // Check if there is a next page
  if (paginatedCoins.hasNextPage && paginatedCoins.nextCursor) {
    // Recursively get coins from the next page and concatenate them
    const nextPageCoins = await getAllCoins(
      client,
      address,
      coinType,
      paginatedCoins.nextCursor
    );
    return currentCoins.concat(nextPageCoins);
  }

  // Return the accumulated coins if no more pages
  return currentCoins;
}

export { getAllCoins };
