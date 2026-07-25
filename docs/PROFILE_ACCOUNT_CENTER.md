# Personal Profile & Account Center

The Profile tab is a personal fitness control center rather than a settings
button list. It presents:

- authenticated identity or an honest local-use state;
- a summary built through `TrainingRepository`,
  `WeeklyTrainingReviewCalculator`, and `TrendWeightCalculator`;
- training goal, experience, equipment, preferences, and coaching style stored
  as `USER_PROVIDED` items in the Stage 3 `AiCoachLocalRepository`;
- AI memory counts, suggestion history, and the current evidence architecture;
- existing training, weekly review, weight, diet, and water entry points;
- cloud export through `export-user-data`, a separate current-namespace local
  JSON export, and deletion through `delete-account`;
- runtime package version/build metadata and Flutter's license page.

Cloud export never claims to contain local-only AI memory, training templates,
or rest overrides. Account deletion requires the exact backend confirmation
phrase. Local cleanup and sign-out only begin after the remote function
succeeds, and cleanup uses the namespace captured for the authenticated user.

Not implemented without backend or platform alignment: remote avatars,
structured profile/AI/suggestion cross-device sync, health-platform
integration, notification preferences, and a global unit or theme system.
