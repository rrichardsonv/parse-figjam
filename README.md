# parse-figjam
Claude skill for parsing figjam diagrams using the figma json api

## Setup

1. Install dependencies

```
brew install jq
```

****

2. Clone the repo into the skills directory

```
cd ~/.claude
mkdir -p ./skills
cd skills
git clone git@github.com:rrichardsonv/parse-figjam.git
cd parse-figjam
chmod +x ./fetch_figjam.sh
cp .env.example .env
```

3. Generate an access token with `file_content:read` scope in figma and add it to your `.env`

https://developers.figma.com/docs/rest-api/authentication/#generate-a-personal-access-token

<img width="600" alt="Image" src="https://github.com/user-attachments/assets/d1769ee4-834d-48f8-81ce-0f54d045df60" />

4. Verify that it shows up in claude code by running `/skills` you should see a `/parse-figjam` option available

## Usage

1. Copy the link to a section in a figjam (note: a subsection titled `Legend` with examples of how colors/connector types map to meaning can help provide hints)

<img width="600" alt="Image" src="https://github.com/user-attachments/assets/b7cb156e-508d-419d-a4fb-b7a0f7db2365" />

2. open up claude code and paste the url in as a param to the skill

```
/parse-figjam <link to figjam section>
```

3. Follow the prompts to direct/refine it's output
