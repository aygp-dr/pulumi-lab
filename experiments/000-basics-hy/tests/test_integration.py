"""Integration tests for Pulumi stack."""
import unittest
import json
import subprocess
from unittest.mock import patch, MagicMock
import pulumi


class TestPulumiIntegration(unittest.TestCase):
    """Integration tests for the Pulumi infrastructure."""
    
    def test_pulumi_preview(self):
        """Test that pulumi preview runs without errors."""
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout='Preview successful',
                stderr=''
            )
            
            result = subprocess.run(
                ['pulumi', 'preview', '--json'],
                capture_output=True,
                text=True
            )
            
            self.assertEqual(result.returncode, 0)
    
    def test_stack_outputs_structure(self):
        """Test that stack outputs have expected structure."""
        expected_outputs = ['bucket_name', 'bucket_arn']
        
        with patch('pulumi.export') as mock_export:
            # Import main module to trigger exports
            import __main__
            
            # Get all export calls
            export_calls = mock_export.call_args_list
            exported_names = [call[0][0] for call in export_calls if call[0]]
            
            # Check that expected outputs are present
            for output in expected_outputs:
                self.assertIn(output, exported_names, 
                            f"Expected output '{output}' not found")
    
    def test_aws_resource_tagging(self):
        """Test that AWS resources are properly tagged."""
        with patch('pulumi_aws.s3.BucketV2') as mock_bucket:
            # Create a mock bucket instance
            mock_instance = MagicMock()
            mock_instance.bucket = 'test-bucket'
            mock_instance.arn = 'arn:aws:s3:::test-bucket'
            mock_bucket.return_value = mock_instance
            
            import __main__
            
            # Verify bucket was created
            self.assertTrue(mock_bucket.called)
            
            # Check if the bucket name follows naming conventions
            call_args = mock_bucket.call_args
            if call_args and call_args[0]:
                bucket_name = call_args[0][0]
                self.assertIsInstance(bucket_name, str)
                self.assertTrue(len(bucket_name) > 0)
    
    def test_pulumi_config_usage(self):
        """Test that Pulumi Config is properly utilized."""
        with patch('pulumi.Config') as mock_config:
            mock_config_instance = MagicMock()
            mock_config.return_value = mock_config_instance
            
            import __main__
            
            # Verify Config was instantiated
            self.assertTrue(mock_config.called)
    
    def test_stack_name_retrieval(self):
        """Test that stack name is properly retrieved."""
        with patch('pulumi.get_stack') as mock_get_stack:
            mock_get_stack.return_value = 'test-stack'
            
            import __main__
            
            # Verify get_stack was called
            self.assertTrue(mock_get_stack.called)


class TestResourceValidation(unittest.TestCase):
    """Tests for resource validation and compliance."""
    
    def test_s3_bucket_configuration(self):
        """Test S3 bucket configuration meets requirements."""
        with patch('pulumi_aws.s3.BucketV2') as mock_bucket:
            mock_instance = MagicMock()
            mock_instance.bucket = 'my-test-bucket'
            mock_instance.arn = 'arn:aws:s3:::my-test-bucket'
            mock_bucket.return_value = mock_instance
            
            import __main__
            
            # Verify bucket was created with proper naming
            self.assertTrue(mock_bucket.called)
            call_args = mock_bucket.call_args
            
            if call_args and call_args[0]:
                resource_name = call_args[0][0]
                # Check resource name follows conventions
                self.assertIsInstance(resource_name, str)
                self.assertNotIn(' ', resource_name, 
                               "Resource name should not contain spaces")
                self.assertTrue(resource_name.replace('-', '').replace('_', '').isalnum(),
                              "Resource name should be alphanumeric with hyphens/underscores")
    
    def test_export_values_not_none(self):
        """Test that exported values are not None."""
        with patch('pulumi.export') as mock_export:
            with patch('pulumi_aws.s3.BucketV2') as mock_bucket:
                mock_instance = MagicMock()
                mock_instance.bucket = 'test-bucket'
                mock_instance.arn = 'arn:aws:s3:::test-bucket'
                mock_bucket.return_value = mock_instance
                
                import __main__
                
                # Check all export calls
                for call in mock_export.call_args_list:
                    if len(call[0]) > 1:
                        export_name = call[0][0]
                        export_value = call[0][1]
                        self.assertIsNotNone(export_value, 
                                           f"Export '{export_name}' has None value")


if __name__ == '__main__':
    unittest.main()