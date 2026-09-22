#!/usr/bin/env node

import { appendFileSync, readFileSync } from "node:fs";

const [inputPath, outputPath] = process.argv.slice(2);

if (!inputPath || !outputPath) {
  console.error("Usage: parse-preview-json.mjs <json-file> <github-output-file>");
  process.exit(2);
}

const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);

const requiredString = (value, path) => {
  if (typeof value !== "string" || value.length === 0 || /[\r\n]/.test(value)) {
    throw new Error(`${path} must be a non-empty single-line string`);
  }
  return value;
};

const stringArray = (value, path) => {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.some((item) => typeof item !== "string" || /[\r\n]/.test(item))) {
    throw new Error(`${path} must be an array of single-line strings when present`);
  }
  return value;
};

const writeOutput = (name, value) => {
  const stringValue = String(value);
  if (/[\r\n]/.test(stringValue)) {
    throw new Error(`Refusing to write multiline output: ${name}`);
  }
  appendFileSync(outputPath, `${name}=${stringValue}\n`, "utf8");
};

try {
  const payload = JSON.parse(readFileSync(inputPath, "utf8"));
  if (!isObject(payload) || !isObject(payload.preview) || !isObject(payload.deployment)) {
    throw new Error("Wrangler preview JSON must contain object properties preview and deployment");
  }

  const preview = payload.preview;
  const deployment = payload.deployment;
  const previewId = requiredString(preview.id, "preview.id");
  const previewName = requiredString(preview.name, "preview.name");
  const deploymentId = requiredString(deployment.id, "deployment.id");
  const previewUrls = stringArray(preview.urls, "preview.urls");
  const deploymentUrls = stringArray(deployment.urls, "deployment.urls");
  const previewUrl = previewUrls[0] ?? "";
  const deploymentUrl = deploymentUrls[0] ?? "";
  const primaryUrl = previewUrl || deploymentUrl;

  writeOutput("preview_name", previewName);
  writeOutput("preview_id", previewId);
  writeOutput("deployment_id", deploymentId);
  writeOutput("preview_url", previewUrl);
  writeOutput("deployment_url", primaryUrl);
  writeOutput("version_url", deploymentUrl);
  writeOutput("version_id", deploymentId);
  writeOutput("preview_urls", JSON.stringify(previewUrls));
  writeOutput("deployment_urls", JSON.stringify(deploymentUrls));
} catch (error) {
  console.error(`Invalid Wrangler preview JSON: ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
}
