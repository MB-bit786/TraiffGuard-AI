# Implementation Plan - Final Theme Polish (Edit Audit & Terms)

This plan covers the remaining theme implementation for the Edit Audit and Terms & Conditions screens to ensure full support for Light and Dark modes.

## User Review Required

> [!IMPORTANT]
> The Edit Audit screen will follow the same design pattern as the Invoice Entry form, using a light surface for inputs in Light Mode and the "Navy Surface" in Dark Mode.

## Proposed Changes

### 1. Edit Audit Screen
- **[MODIFY] [edit_audit_screen.dart](file:///C:/Users/MohammadBookwala/StudioProjects/hscode_auditor/lib/features/audit/presentation/pages/edit_audit_screen.dart)**:
    - Update `Scaffold` and `AppBar` to use theme-aware colors.
    - Make `_buildTextField`, `_buildCargoDescriptionField`, and `_buildDropdown` fully responsive to the current brightness.
    - Update `_buildTariffSearchResults` to use theme-aware container and divider colors.
    - Update `_buildInfoNote` for better contrast in Light Mode.

### 2. Terms & Conditions Screen
- **[MODIFY] [terms_conditions_screen.dart](file:///C:/Users/MohammadBookwala/StudioProjects/hscode_auditor/lib/features/profile/presentation/pages/terms_conditions_screen.dart)**:
    - Update `Scaffold` and `AppBar` backgrounds.
    - Refine `_buildLegalHeader` and `_buildLegalSection` text styles to ensure legibility on light backgrounds.
    - Make the bottom `_buildActionBlock` theme-aware (switch from Navy Mid to white in Light Mode).

## Verification Plan

### Manual Verification
1.  **Edit Audit**: Navigate to an existing audit and long-press to edit. Toggle themes and verify the form adapts correctly.
2.  **Terms**: Open "Platform Terms of Service" from the Profile screen. Toggle themes and verify the legal text remains highly readable.
3.  **Gatekeeper Mode**: (Optional) Test the initial terms acceptance screen during a new signup flow in both modes.
