# AI Smart Weighing POS - Dataset Starter Pack

## Scope
- Fresh produce classes: 76 (46 vegetables, 6 leafy-green classes, 25 fruits).
- Optional packaged-product classes: 7 (kept separate from fresh produce).
- Labeled images: 336 total.
- Each class has one source image normalized to 640 x 640 plus three synthetic rotations: 90, 180, and 270 degrees.

## Files
- `images/fresh_produce/<class_id>/` - image-classification seed folders.
- `images/optional_packaged_products/<class_id>/` - optional packaged SKUs.
- `class_map.csv` - stable class ID, English label, local/Roman label, and category.
- `image_manifest.csv` - one row per image, including source and augmentation name.
- `sku_mapping_template.csv` - fill in your POS SKU IDs, units, and price fields.
- `real_capture_log_template.csv` - log actual photos captured above the shop scale.
- `inference_spec.json` - suggested camera, confidence, BLE, and cart event settings.
- `dataset_summary.json` - class and file counts.
- `reference/user_scale_camera_reference.jpg` - your uploaded scale-scene reference; not a labeled product image.
- `AI_Smart_Weighing_POS_Training_Guide.pdf` - PDF implementation and training brief (also provided separately).

## Critical limitation - read before training
This is a <b>starter/seed dataset</b>, not a production-ready training corpus. The four files per class are synthetic orientation augmentations of one seed image, NOT four independent photographs, NOT true camera viewpoints, and NOT separate specimens. Some catalog images are low-resolution 256 px POS images that have been upscaled to a common input size; upscaling does not create new detail. Some catalog-style pictures may include decorative leaves, flowers, groups, or cut pieces. Replace/supplement these with real images of the complete produce as it appears on your weighing tray.

Do not expect robust 0.2-second recognition from this pack alone. A 200 ms target applies to model inference after frame capture and preprocessing, and must be measured on the target hardware.

## Real capture plan
For each SKU, start with 150-300 real photos for a pilot; expand toward 300-500+ per SKU for production, especially for visually similar varieties. Capture the exact overhead camera view used at the store. Include: centered and edge placement, diagonal, horizontal/vertical orientations, naturally rotated items, large/small specimens, different stock batches and days, leaves/stems on/off, normal blemishes, wet/dry surfaces, and normal shop lighting. Use the same tray and camera position.

## Training rules
- Use image classification if one SKU is placed on the scale at a time; crop a fixed tray ROI first.
- Use an object detector only if multiple different products may be on the scale at once. The current pack has no bounding-box annotations.
- Split real photos by capture session/day/batch (e.g. 70/15/15). Do not let rotated variants from the same seed cross splits.
- Keep a separate test set from real store sessions. Include an `unknown/other` rejection path.
- Join `class_map.csv` to your POS master using `sku_mapping_template.csv`. Never infer price from the image model.

## Runtime flow
1. BLE weight streams in grams.
2. Wait for the scale stable flag (preferred) or a tuned consecutive-reading stability rule.
3. Capture the tray ROI and run local model inference.
4. High-confidence prediction may become a cart candidate; medium/low confidence requires cashier confirmation or recapture.
5. Add SKU + stable grams + price from POS master once per unique weigh event.
6. When the scale returns to zero, close the event and re-arm.

## Starting confidence policy (calibrate on your own test set)
- >= 0.92 and clear top-1/top-2 margin: candidate for auto-add.
- 0.75-0.92: show top-3 choices for cashier confirmation.
- < 0.75 or unknown/ambiguous: do not auto-add.

## Price calculation
`amount = weight_g / 1000 * price_per_kg`
Example only: 650 g at Rs 80/kg = Rs 52.00. The POS database remains the source of product price and billing unit.
