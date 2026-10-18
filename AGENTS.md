<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->

- Preserve existing providers, query hooks and transactional sale RPCs when redesigning; these keep records and billing stable.
- Validate inventory in database triggers, audit manual adjustments, and restrict negative-stock opt-in to the shop owner; browser validation alone cannot prevent concurrent overselling.
- Product search uses actual multilingual names, SKU and barcode fields plus a shared alias matcher; blank identifiers must never be invented.
- Checkout renders saved sales and saved line items rather than reconstructing an invoice from the cleared cart; retries retain their client reference.
- Use Vitest for application tests; keep Bun's global runtime types out of browser and Worker compilation to avoid incompatible fetch types.
