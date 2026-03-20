#!/usr/bin/env bash


# Usage:                                                                                                                                                                                                  
#   fetch_figjam <figjam_url>                                                                                                                                                                             
#                                                                                                                                                                                                         
# Fetches a FigJam board from the Figma API and saves it as a prettified JSON file.                                                                                                                       
#                                                                                                                                                                                                         
# Requires:                                                                                                                                                                                               
#   - FIGMA_API_KEY environment variable set to a Figma personal access token                                                                                                                             
#   - jq installed (brew install jq)                                                                                                                                                                      
#                                                                                                                                                                                                         
# URL format:                                                                                                                                                                                             
#   https://www.figma.com/board/<board_key>/<board_name>?node-id=<node_id>                                                                                                                                
#               
# Output:
#   <board_name>_<board_key>_<node_id>_v<version>.json in the current directory                                                                                                                           
#   Version auto-increments based on existing files matching the same prefix.                                                                                                                             
#                                                                                                                                                                                                         
# Examples:                                                                                                                                                                                               
#   fetch_figjam "https://www.figma.com/board/ABCDEFG/Test-figjam?node-id=1-2"                                                                                                             
#   fetch_figjam "https://www.figma.com/board/ABCDEFG/Test-figjam"
fetch_figjam() {
  local figjam_url="$1"

  if [ -z "$figjam_url" ]; then
    echo "Usage: fetch_figjam <figjam_url>"
    return 1
  fi

  # Check for API key
  if [ -z "$FIGMA_API_KEY" ]; then
    echo "Error: FIGMA_API_KEY is not set."
    echo "Generate a personal access token at: https://developers.figma.com/docs/rest-api/authentication/#generate-a-personal-access-token"
    echo "Then add to your shell profile:"
    echo "  export FIGMA_API_KEY=\"your-token-here\""
    return 1
  fi

  # Check for jq
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed."
    echo "Install with: brew install jq"
    return 1
  fi

  # Process the board key (second path segment after /board/)
  local figma_board_key
  figma_board_key="$(echo "$figjam_url" | sed -n 's|.*/board/\([^/]*\)/.*|\1|p')"
  if [ -z "$figma_board_key" ]; then
    echo "Error: Could not extract board key from URL."
    echo "Expected URL format: https://www.figma.com/board/<key>/<name>?node-id=..."
    return 1
  fi

  # Process the node-id (default to 0:1 if not present)
  local figma_node_id
  local raw_node_id
  raw_node_id="$(echo "$figjam_url" | sed -n 's|.*[?&]node-id=\([^&]*\).*|\1|p')"
  if [ -z "$raw_node_id" ]; then
    figma_node_id="0:1"
  else
    # Convert dash-separated to colon-separated (e.g. 1-2 -> 1:2)
    figma_node_id="$(echo "$raw_node_id" | tr '-' ':')"
  fi

  # Process the file name
  local figma_board_name
  figma_board_name="$(echo "$figjam_url" | sed -n 's|.*/board/[^/]*/\([^?]*\).*|\1|p')"
  # Strip trailing slash if any, replace special characters with dashes
  figma_board_name="$(echo "$figma_board_name" | sed 's|/$||' | sed 's/[^a-zA-Z0-9_-]/-/g')"
  if [ -z "$figma_board_name" ]; then
    figma_board_name="figjam-export"
  fi

  # Resolve the script's directory and ensure output directory exists
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  local output_dir="${script_dir}/output"
  mkdir -p "$output_dir"

  # Build the filename prefix (use underscores to join parts)
  local figma_node_id_safe
  figma_node_id_safe="$(echo "$figma_node_id" | tr ':' '-')"
  local file_prefix="${figma_board_name}_${figma_board_key}_${figma_node_id_safe}"

  # Count existing versions matching this prefix
  local existing_count
  existing_count="$(ls -1 "${output_dir}/${file_prefix}"_v*.json 2>/dev/null | wc -l | tr -d ' ')"
  local figma_version_count=$(( existing_count + 1 ))

  local output_file="${output_dir}/${file_prefix}_v${figma_version_count}.json"

  # URL-encode the node id for the API request
  local encoded_node_id
  encoded_node_id="$(printf '%s' "$figma_node_id" | sed 's/:/%3A/g')"

  # Fetch the resource
  echo "Fetching FigJam board: $figma_board_name (node $figma_node_id)..."
  local response
  response="$(curl -s -H "X-Figma-Token: $FIGMA_API_KEY" \
    "https://api.figma.com/v1/files/${figma_board_key}/nodes?ids=${encoded_node_id}&geometry=paths")"

  # Check for errors in response
  if echo "$response" | jq -e '.err' &>/dev/null; then
    echo "Error from Figma API:"
    echo "$response" | jq .
    return 1
  fi

  # Prettify and save
  echo "$response" | jq '.' > "$output_file"
  echo "Saved to: $output_file"
}

# Allow sourcing or direct execution
if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
  fetch_figjam "$@"
  exit $?
fi
