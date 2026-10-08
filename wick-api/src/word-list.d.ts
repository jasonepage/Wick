// The `word-list` package ships no types: its default export is the absolute path
// to a newline-separated English words file (dwyl's words.txt).
declare module "word-list" {
  const path: string;
  export default path;
}
