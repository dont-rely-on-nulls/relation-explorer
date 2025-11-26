# Karuta Relational Explorer

A macOS application for exploring Karuta relational language queries.

## Features

- **Split View Interface**: Code editor on the left, results table on the right
- **Socket Communication**: Sends queries to a Karuta server via raw TCP socket
- **XML Response Parsing**: Parses XML table responses and renders them as a native table
- **Real-time Connection Status**: Visual indicator showing connection state

## Usage

1. **Connect to Server**
   - Enter the host (default: `localhost`) and port (default: `5555`)
   - Click "Connect" to establish a connection to your Karuta server
   - Green indicator shows when connected

2. **Write Queries**
   - Type your Karuta query in the left editor panel
   - Example: `nat[A],nat[B],plus[A,B,4]?`

3. **Execute**
   - Click the "Execute" button to send the query to the server
   - Results will appear in the table on the right

## Expected XML Response Format

The server should respond with XML in the following format:

```xml
<table>
  <columns>
    <column>A</column>
    <column>B</column>
  </columns>
  <rows>
    <row>
      <cell>0</cell>
      <cell>4</cell>
    </row>
    <row>
      <cell>1</cell>
      <cell>3</cell>
    </row>
    <row>
      <cell>2</cell>
      <cell>2</cell>
    </row>
    <row>
      <cell>3</cell>
      <cell>1</cell>
    </row>
    <row>
      <cell>4</cell>
      <cell>0</cell>
    </row>
  </rows>
</table>
```

## Building

Open the project in Xcode and build:

```bash
open RelationalExplorer.xcodeproj
```

Or build from command line:

```bash
xcodebuild -scheme RelationalExplorer -configuration Debug build
```

## Requirements

- macOS 15.7+
- Xcode 17.0+
- Swift 5.0+

## Network Permissions

The app includes entitlements for:
- `com.apple.security.network.client` - Outgoing network connections
- `com.apple.security.network.server` - Listening for connections (if needed)
