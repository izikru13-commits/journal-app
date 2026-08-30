// Zikkit (זיקית) — app root.
function App() {
  const [profile, setProfile] = React.useState(() => getProfile());

  return (
    <AppShell profile={profile}>
      <WordleGame profile={profile} onProfileUpdate={setProfile} />
    </AppShell>
  );
}

ReactDOM.render(<App />, document.getElementById("root"));
