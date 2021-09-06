package main

import (
	"flag"
	"io"
	"log"
	"os"

	"github.com/diskfs/go-diskfs/filesystem/iso9660"
)

func main() {
	isoFilename := flag.String("iso", "", "output ISO filename")
	flag.Parse()

	err := run(*isoFilename)
	if err != nil {
		log.Fatal(err)
	}
}

func run(isoFilename string) error {
	file, err := os.Create(isoFilename)
	if err != nil {
		return err
	}
	defer file.Close()

	// empty string workspace will create a directory in the
	// system temp directory.
	// https://github.com/diskfs/go-diskfs/pull/101
	workspace := ""
	fs, err := iso9660.Create(file, 0, 0, 2048, workspace)
	if err != nil {
		return err
	}

	if err = fs.Mkdir("/"); err != nil {
		return err
	}

	if err := addFile(fs, "meta-data"); err != nil {
		return err
	}

	if err := addFile(fs, "user-data"); err != nil {
		return err
	}

	if err := fs.Finalize(iso9660.FinalizeOptions{
		RockRidge:        true,
		VolumeIdentifier: "cidata",
	}); err != nil {
		return err
	}

	return nil
}

func addFile(fs *iso9660.FileSystem, filename string) error {
	src, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer src.Close()

	dest, err := fs.OpenFile("/"+filename, os.O_CREATE|os.O_WRONLY)
	if err != nil {
		return err
	}

	_, err = io.Copy(dest, src)
	if err != nil {
		return err
	}

	return nil
}
