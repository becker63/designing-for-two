package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/alecthomas/kong"
	frpv1 "github.com/fatedier/frp/pkg/config/v1"
	"github.com/invopop/jsonschema"
)

/* =========================
   CLI
   ========================= */

type CLI struct {
	OutDir string `help:"Output directory" required:""`
}

/* =========================
   Schema generation
   ========================= */

type SchemaTarget struct {
	Dir             string
	Filename        string
	Example         interface{}
	PatchProperties map[string]string
}

func generateSchema(filepath string, example interface{}, patch map[string]string) error {
	schema := jsonschema.Reflect(example)

	rawBytes, err := json.Marshal(schema)
	if err != nil {
		return fmt.Errorf("marshal schema: %w", err)
	}

	var normalized map[string]interface{}
	if err := json.Unmarshal(rawBytes, &normalized); err != nil {
		return fmt.Errorf("unmarshal schema: %w", err)
	}

	defsKey := "$defs"
	if _, ok := normalized["definitions"]; ok {
		defsKey = "definitions"
	}

	defs, ok := normalized[defsKey].(map[string]interface{})
	if !ok {
		return fmt.Errorf("no %q found in schema", defsKey)
	}

	for patchPath, patchType := range patch {
		parts := strings.Split(patchPath, ".")
		if len(parts) != 2 {
			fmt.Fprintf(os.Stderr, "⚠️ invalid patch key %q\n", patchPath)
			continue
		}

		schemaName, propName := parts[0], parts[1]

		targetSchema, ok := defs[schemaName].(map[string]interface{})
		if !ok {
			fmt.Fprintf(os.Stderr, "⚠️ schema %q not found\n", schemaName)
			continue
		}

		props, ok := targetSchema["properties"].(map[string]interface{})
		if !ok {
			fmt.Fprintf(os.Stderr, "⚠️ schema %q has no properties\n", schemaName)
			continue
		}

		switch patchType {
		case "any":
			props[propName] = map[string]interface{}{}
		case "array<any>":
			props[propName] = map[string]interface{}{
				"type":  "array",
				"items": map[string]interface{}{},
			}
		case "object<any>":
			props[propName] = map[string]interface{}{
				"type":                 "object",
				"additionalProperties": map[string]interface{}{},
			}
		default:
			fmt.Fprintf(os.Stderr, "⚠️ unknown patch type %q\n", patchType)
		}
	}

	file, err := os.Create(filepath)
	if err != nil {
		return fmt.Errorf("create schema file: %w", err)
	}
	defer file.Close()

	enc := json.NewEncoder(file)
	enc.SetIndent("", "  ")
	return enc.Encode(normalized)
}

/* =========================
   KCL helpers
   ========================= */

func runCommand(name string, args []string, dir string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

func runKCLModInit(dir string) error {
	return runCommand("kcl", []string{"mod", "init"}, dir)
}

func runKCLImport(schemaFile, dir string) error {
	return runCommand("kcl", []string{"import", "-m", "jsonschema", schemaFile, "--force"}, dir)
}

func removeMainK(dir string) error {
	mainK := filepath.Join(dir, "main.k")
	if err := os.Remove(mainK); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

func ensureDir(dir string) error {
	return os.MkdirAll(dir, 0755)
}

func handleSchema(target SchemaTarget) error {
	fmt.Printf("📦 %s\n", target.Dir)

	if err := ensureDir(target.Dir); err != nil {
		return err
	}
	if err := runKCLModInit(target.Dir); err != nil {
		return err
	}
	if err := removeMainK(target.Dir); err != nil {
		return err
	}

	schemaPath := filepath.Join(target.Dir, target.Filename)
	if err := generateSchema(schemaPath, target.Example, target.PatchProperties); err != nil {
		return err
	}

	return runKCLImport(target.Filename, target.Dir)
}

/* =========================
   Targets (always all)
   ========================= */

func buildTargets(root string) []SchemaTarget {
	return []SchemaTarget{
		{
			Dir:      filepath.Join(root, "frpc"),
			Filename: "frpcschema.json",
			Example:  &frpv1.ClientConfig{},
			PatchProperties: map[string]string{
				"ClientConfig.proxies":  "array<any>",
				"ClientConfig.visitors": "array<any>",
			},
		},
		{
			Dir:      filepath.Join(root, "frps"),
			Filename: "frpsschema.json",
			Example:  &frpv1.ServerConfig{},
		},
		{
			Dir:      filepath.Join(root, "frpc", "tcp_proxy"),
			Filename: "tcp_proxy.schema.json",
			Example:  &frpv1.TCPProxyConfig{},
		},
	}
}

/* =========================
   main
   ========================= */

func main() {
	var cli CLI
	kong.Parse(&cli)

	outDir, err := filepath.Abs(cli.OutDir)
	if err != nil {
		log.Fatalf("invalid out-dir: %v", err)
	}

	if outDir == "/" {
		log.Fatal("refusing to write to filesystem root")
	}

	for _, target := range buildTargets(outDir) {
		if err := handleSchema(target); err != nil {
			log.Fatalf("❌ %s: %v", target.Dir, err)
		}
	}
}
